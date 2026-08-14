import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/session_service.dart';
import 'home_screen.dart';

/// Bienvenida al terminar de crear la cuenta.
///
/// Es el cierre del registro: el correo quedó verificado, los datos guardados y
/// los documentos enviados. La cuenta ya sirve mientras el equipo revisa la
/// identidad, y eso se dice acá para que nadie se quede esperando una
/// aprobación antes de usar la app.
///
/// Acá va a colgar después el tutorial guiado.
class WelcomeScreen extends StatefulWidget {
  final String email;

  const WelcomeScreen({super.key, required this.email});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color _marca = Color(0xFF78BF32);

  @override
  void initState() {
    super.initState();
    // La sesión del dispositivo se abre acá, que es donde termina el registro:
    // antes lo hacía la pantalla de verificación exitosa, que ya no es el
    // último paso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionService>(context, listen: false)
          .registerSession(widget.email);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              // Marca, del mismo tamaño que en el resto del registro.
              const Text(
                'Tu',
                style: TextStyle(
                  fontFamily: 'TitanOne',
                  fontSize: 64,
                  color: _marca,
                  height: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Du',
                style: TextStyle(
                  fontFamily: 'TitanOne',
                  fontSize: 64,
                  color: _marca,
                  height: 0.8,
                ),
              ),
              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _marca.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_outlined,
                    size: 56, color: _marca),
              ),
              const SizedBox(height: 28),

              Text(
                context.tr('welcome_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('welcome_body'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Lo que ya quedó hecho, para que el registro se sienta cerrado.
              _logro(context.tr('welcome_step_email')),
              const SizedBox(height: 10),
              _logro(context.tr('welcome_step_data')),
              const SizedBox(height: 10),
              _logro(context.tr('welcome_step_docs'), enRevision: true),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeScreen(userEmail: widget.email),
                    ),
                    (ruta) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _marca,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    context.tr('welcome_start'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Un paso ya cumplido. El de los documentos se marca distinto: está enviado,
  /// no aprobado, y prometer lo segundo sería mentir.
  Widget _logro(String texto, {bool enRevision = false}) {
    final color = enRevision ? const Color(0xFFB26A00) : _marca;

    return Row(
      children: [
        Icon(
          enRevision ? Icons.hourglass_top : Icons.check_circle,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
                fontSize: 14, color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }
}
