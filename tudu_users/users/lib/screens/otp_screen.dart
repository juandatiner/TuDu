import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/auth_api.dart';
import '../services/session_service.dart';
import 'verification_success_screen.dart';
import 'registration_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  /// true cuando el backend simuló el envío (`DEV_MODE`): no llega ningún
  /// correo, así que el código maestro se rellena solo.
  final bool devMode;

  const OtpScreen({super.key, required this.email, this.devMode = false});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _canResend = false;
  // El código quedó mal: los seis recuadros se marcan en rojo hasta que se
  // vuelva a escribir. Antes solo salía un SnackBar y los recuadros seguían
  // verdes al enfocarlos.
  bool _codigoInvalido = false;
  int _resendTimer = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Pre-llenar solo cuando el backend dijo que el envío fue simulado. Antes
    // estaba atado a una cuenta concreta escrita en el código, así que con
    // cualquier otro correo había que teclear el maestro a mano.
    if (widget.devMode) _fillDevCode();
  }

  void _fillDevCode() {
    const devCode = '123456';
    for (int i = 0; i < devCode.length && i < _controllers.length; i++) {
      _controllers[i].text = devCode[i];
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    _resendTimer = 30;
    _canResend = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  /// El código quedó bien: se muestra el "verificación exitosa" siempre, exista
  /// la cuenta o no. Antes, quien todavía no estaba registrado saltaba directo
  /// al formulario y nunca veía que su correo había quedado verificado; esa
  /// pantalla decide sola a dónde seguir.
  void _checkUserAfterOtp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationSuccessScreen(email: widget.email),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) {
      setState(() => _codigoInvalido = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('otp_incomplete')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Guarda la sesión (acceso + refresco) al verificar correctamente.
      await AuthApi.verificarCodigo(
        email: widget.email,
        codigo: _otpCode,
        deviceId: Provider.of<SessionService>(context, listen: false).deviceId,
      );

      _checkUserAfterOtp();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _codigoInvalido = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('otp_connection_error')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendTimer = 30;
      _isLoading = true;
    });

    try {
      await AuthApi.enviarCodigo(widget.email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('otp_resent')),
          backgroundColor: Colors.green,
        ),
      );
      _startResendTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('otp_connection_error')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _canResend = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Rojo si el código falló; si no, verde mientras el recuadro tiene el foco
  /// y gris en reposo. Nunca los dos colores encima del mismo campo.
  Color _colorBorde(int index) {
    if (_codigoInvalido) return const Color(0xFFF44336);
    return _focusNodes[index].hasFocus
        ? const Color(0xFF78BF32)
        : Colors.black26;
  }

  void _onOtpChanged(int index, String value) {
    if (_codigoInvalido) setState(() => _codigoInvalido = false);
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  /// Ancho de cada recuadro del código.
  ///
  /// Crece con el tamaño de letra del teléfono —si no, con Dynamic Type grande
  /// el dígito quedaba apretado contra el borde— pero nunca más de lo que cabe:
  /// son seis en fila y al pasarse se cortaban por los lados.
  double _anchoRecuadro(BuildContext context) {
    const base = 45.0;
    const separacionMinima = 6.0;
    const margenPantalla = 24.0 * 2;

    final escala = MediaQuery.textScalerOf(context).scale(base) / base;
    final disponible =
        MediaQuery.sizeOf(context).width - margenPantalla - separacionMinima * 5;
    final tope = disponible / 6;

    return (base * escala).clamp(32.0, tope < 32.0 ? 32.0 : tope);
  }

  @override
  Widget build(BuildContext context) {
    final anchoRecuadro = _anchoRecuadro(context);

    return Scaffold(
      body: Container(
        color: const Color(0xFFF4F2F2),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Column(
                  children: [
                    Text(
                      'Tu',
                      style: TextStyle(
                        fontFamily: 'TitanOne',
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF78BF32),
                        height: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Du',
                      style: TextStyle(
                        fontFamily: 'TitanOne',
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF78BF32),
                        height: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Título
                Text(
                  context.tr('otp_title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  '${context.tr('otp_subtitle')}\n${widget.email}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Campos OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: anchoRecuadro,
                      height: anchoRecuadro * 55 / 45,
                      child: Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _colorBorde(index), width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _colorBorde(index), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _colorBorde(index), width: 2),
                            ),
                          ),
                          onChanged: (value) => _onOtpChanged(index, value),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),

                // Botón Verificar
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          context.tr('verify'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Reenviar código
                TextButton(
                  onPressed: _canResend ? _resendOtp : null,
                  child: Text(
                    _canResend
                        ? context.tr('otp_resend')
                        : '${context.tr('otp_resend_in')} ${_resendTimer}s',
                    style: TextStyle(
                      color: _canResend ? const Color(0xFF78BF32) : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Cambiar email
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.tr('otp_change_email'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
