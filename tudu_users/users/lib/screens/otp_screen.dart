import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/api.dart';
import '../services/auth_api.dart';
import '../services/session_service.dart';
import 'verification_success_screen.dart';
import 'registration_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Pre-llenar con código de desarrollo solo para la cuenta de prueba
    if (widget.email == 'cosmodavid2009@gmail.com') {
      _fillDevCode();
    }
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

  Future<void> _checkUserAfterOtp() async {
    try {
      final existe = await AuthApi.existeUsuario(widget.email);

        if (existe) {
          // Usuario existe, ir a verificación exitosa
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => VerificationSuccessScreen(email: widget.email)),
          );
        } else {
          // Usuario no existe, ir a registro
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(email: widget.email)),
          );
        }
    } catch (e) {
      // Error de conexión, asumir no existe
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RegistrationScreen(email: widget.email)),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el código completo de 6 dígitos'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Verifica tu conexión a internet.'),
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
          const SnackBar(
            content: Text('Código OTP reenviado'),
            backgroundColor: Colors.green,
          ),
        );
        _startResendTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
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

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Verificación',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Ingresa el código de 6 dígitos enviado a\n${widget.email}',
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
                      width: 45,
                      height: 55,
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
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF78BF32), width: 2),
                          ),
                        ),
                        onChanged: (value) => _onOtpChanged(index, value),
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
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verificar',
                          style: TextStyle(
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
                        ? 'Reenviar código'
                        : 'Reenviar en ${_resendTimer}s',
                    style: TextStyle(
                      color: _canResend ? const Color(0xFF78BF32) : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Cambiar email
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cambiar correo electrónico',
                    style: TextStyle(
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