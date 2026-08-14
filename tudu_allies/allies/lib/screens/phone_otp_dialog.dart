import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/phone_api.dart';
import '../widgets/campo_caja.dart';
import '../widgets/validacion_formulario.dart';

/// Diálogo de verificación del teléfono del aliado.
///
/// Devuelve `true` si el número quedó verificado y guardado, `null` si la
/// persona canceló. Es la misma pieza que usa la app de usuarios: en
/// desarrollo el campo llega relleno con el código maestro, igual que la
/// pantalla de OTP del correo.
Future<bool?> mostrarVerificacionTelefono(
  BuildContext context, {
  required String email,
  required String countryCode,
  required String phoneNumber,
  String? countryName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoOtpTelefono(
      email: email,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      countryName: countryName,
    ),
  );
}

class _DialogoOtpTelefono extends StatefulWidget {
  final String email;
  final String countryCode;
  final String phoneNumber;
  final String? countryName;

  const _DialogoOtpTelefono({
    required this.email,
    required this.countryCode,
    required this.phoneNumber,
    this.countryName,
  });

  @override
  State<_DialogoOtpTelefono> createState() => _DialogoOtpTelefonoState();
}

class _DialogoOtpTelefonoState extends State<_DialogoOtpTelefono> {
  static const _codigoDesarrollo = '123456';

  final _controlador = TextEditingController();
  bool _enviando = false;
  bool _verificando = false;
  String? _error;
  bool _tieneFoco = false;

  String get _telefonoCompleto => '${widget.countryCode}${widget.phoneNumber}';

  @override
  void initState() {
    super.initState();
    _enviarCodigo();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final simulado = await TelefonoApi.enviarCodigo(
          email: widget.email, telefono: _telefonoCompleto);
      if (!mounted) return;

      // Solo en desarrollo no llega ningún SMS: ahí se rellena el código
      // maestro. Con SMS real el campo queda vacío.
      if (simulado) _controlador.text = _codigoDesarrollo;
      setState(() => _enviando = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = context.tr('phone_otp_send_error');
      });
    }
  }

  Future<void> _verificar() async {
    final codigo = _controlador.text.trim();

    if (codigo.length != 6) {
      setState(() => _error = context.tr('phone_otp_length'));
      return;
    }

    setState(() {
      _verificando = true;
      _error = null;
    });

    try {
      await TelefonoApi.verificarCodigo(
        email: widget.email,
        codigo: codigo,
        countryCode: widget.countryCode,
        phoneNumber: widget.phoneNumber,
        countryName: widget.countryName,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _error = context.tr('phone_otp_verify_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un solo color de borde a la vez: rojo si el código está mal, verde solo
    // mientras el campo tiene el foco, gris en reposo.
    final colorBorde = _error != null
        ? Validacion.colorError
        : _tieneFoco
            ? CampoColores.marca
            : Colors.black26;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CampoColores.marca.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms_outlined,
                  size: 40, color: CampoColores.marca),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('phone_otp_title'),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('phone_otp_subtitle')}\n$_telefonoCompleto',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: CampoColores.textoSecundario),
            ),
            const SizedBox(height: 20),
            if (_enviando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: CampoColores.marca),
              )
            else
              Focus(
                onFocusChange: (foco) => setState(() => _tieneFoco = foco),
                child: TextField(
                  controller: _controlador,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: Colors.black),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: const TextStyle(
                        color: CampoColores.textoSecundario, letterSpacing: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBorde, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBorde, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBorde, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _verificar(),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_enviando || _verificando) ? null : _verificar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CampoColores.marca,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _verificando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.tr('verify'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _enviando ? null : _enviarCodigo,
                  child: Text(context.tr('phone_otp_resend'),
                      style: const TextStyle(color: CampoColores.marca)),
                ),
                TextButton(
                  onPressed: _verificando ? null : () => Navigator.pop(context),
                  child: Text(context.tr('cancel'),
                      style: const TextStyle(
                          color: CampoColores.textoSecundario)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
