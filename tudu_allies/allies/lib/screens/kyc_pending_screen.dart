import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../services/ally_api.dart';
import '../services/session_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'service_setup_screen.dart';

/// Pantalla de espera para aliados que ya enviaron sus documentos KYC
/// y están pendientes de revisión por parte de un administrador.
///
/// Existe para que un aliado en ese estado NUNCA vuelva a ver el formulario
/// de datos personales: ya los dio, lo único que falta es que lo aprueben.
class KycPendingScreen extends StatefulWidget {
  final String email;

  const KycPendingScreen({super.key, required this.email});

  @override
  State<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends State<KycPendingScreen> {
  bool _isChecking = false;

  /// Vuelve a preguntarle al backend en qué estado quedó la verificación.
  Future<void> _refreshStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // Sin `onLogin`: refrescar el estado nunca debe descartar el registro.
      final data = await AliadoApi.estado(widget.email);

      if (!mounted) return;

      {
        if (data['exists'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AllyHomeScreen(allyEmail: widget.email),
            ),
          );
          return;
        }

        if (data['partial'] == 'service') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceSetupScreen(email: widget.email),
            ),
          );
          return;
        }

        // Sigue en revisión: no hay nada que hacer más que esperar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('still_under_review')),
            backgroundColor: Color(0xFF595959),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('status_check_failed')),
          backgroundColor: Color(0xFFF44336),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _logout() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tu',
                  style: TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78BF32),
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Du',
                  style: TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78BF32),
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF78BF32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    size: 56,
                    color: Color(0xFF78BF32),
                  ),
                ),
                const SizedBox(height: 28),
                Text(context.tr('account_under_review'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ya recibimos tus documentos. Un administrador los está '
                  'revisando y te avisaremos apenas quede aprobada.\n\n'
                  'No necesitas volver a ingresar tus datos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _refreshStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF78BF32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.tr('refresh_status'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _logout,
                  child: Text(context.tr('close_session'),
                    style: TextStyle(color: Color(0xFF595959)),
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
