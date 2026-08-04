import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      await TelefonoApi.enviarCodigo(email: widget.email, telefono: _telefonoCompleto);
      if (!mounted) return;

      // En desarrollo no llega ningún SMS: se rellena el código maestro.
      _controlador.text = _codigoDesarrollo;
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
        _error = 'No se pudo enviar el código';
      });
    }
  }

  Future<void> _verificar() async {
    final codigo = _controlador.text.trim();

    if (codigo.length != 6) {
      setState(() => _error = 'El código tiene 6 dígitos');
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
        _error = 'No se pudo verificar el código';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
            const Text(
              'Verifica tu teléfono',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enviamos un código de 6 dígitos a\n$_telefonoCompleto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),

            if (_enviando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: Color(0xFF78BF32)),
              )
            else
              TextField(
                controller: _controlador,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 10),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _verificar(),
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
                    : const Text('Verificar',
                        style: TextStyle(
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
                  child: const Text('Reenviar'),
                ),
                TextButton(
                  onPressed: _verificando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Color(0xFF595959))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
