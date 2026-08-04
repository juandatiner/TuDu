import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../widgets/validacion_formulario.dart';
import '../services/api.dart';
import '../services/phone_api.dart';

/// Diálogo de verificación del teléfono.
///
/// Devuelve `true` si el número quedó verificado y guardado, `null` si la
/// persona canceló.
///
/// En desarrollo el campo llega relleno con el código maestro para no frenar
/// las pruebas, igual que la pantalla de OTP del correo.
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
    // El diálogo se abre desde los datos personales, ya con sesión: ahí sí
    // aplica el modo oscuro, así que los colores salen del tema y no fijos.
    final tema = context.watch<ThemeProvider>();
    final oscuro = tema.isDarkMode;
    final loc = context.loc;

    final colorTexto =
        oscuro ? ThemeProvider.darkText : ThemeProvider.lightText;
    final colorSecundario = oscuro
        ? ThemeProvider.darkSecondaryText
        : ThemeProvider.lightSecondaryText;
    final colorCampo = oscuro ? ThemeProvider.darkScaffoldBg : Colors.white;

    // Un solo color de borde a la vez: rojo si el código está mal, verde solo
    // mientras el campo tiene el foco, gris en reposo.
    final colorBorde = _error != null
        ? Validacion.colorError
        : _tieneFoco
            ? ThemeProvider.primaryColor
            : (oscuro ? ThemeProvider.darkBorder : Colors.black26);

    return Dialog(
      backgroundColor: oscuro ? ThemeProvider.darkCardBg : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF78BF32).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms_outlined,
                  size: 40, color: Color(0xFF78BF32)),
            ),
            const SizedBox(height: 18),
            Text(
              loc.t('phone_otp_title'),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: colorTexto),
            ),
            const SizedBox(height: 8),
            Text(
              '${loc.t('phone_otp_subtitle')}\n$_telefonoCompleto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colorSecundario),
            ),
            const SizedBox(height: 20),
            if (_enviando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: Color(0xFF78BF32)),
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
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: colorTexto),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle:
                        TextStyle(color: colorSecundario, letterSpacing: 10),
                    filled: true,
                    fillColor: colorCampo,
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
                  backgroundColor: const Color(0xFF78BF32),
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
                    : Text(loc.t('verify'),
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
                  child: Text(loc.t('phone_otp_resend'),
                      style:
                          const TextStyle(color: ThemeProvider.primaryColor)),
                ),
                TextButton(
                  onPressed: _verificando ? null : () => Navigator.pop(context),
                  child: Text(loc.t('cancel'),
                      style: TextStyle(color: colorSecundario)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
