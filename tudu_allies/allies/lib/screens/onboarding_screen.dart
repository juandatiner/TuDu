import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/ally_routing.dart';
import '../services/auth_store.dart';
import '../services/session_service.dart';
import 'dart:async';
import 'home_screen.dart' show kAzulAliado;
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _taglineFadeAnimation;
  late Animation<double> _shimmerAnimation;

  static const Color _bgColor = Color(0xFFF4F2F2);
  static const Color _brandColor = Color(0xFF78BF32);

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _mainController.forward().then((_) {
      _shimmerController.repeat();
    });

    Timer(const Duration(milliseconds: 2000), _resolverDestino);
  }

  /// Si hay una sesión guardada y el servidor la sigue aceptando, se entra
  /// directo. Antes esta pantalla mandaba siempre al login, así que el aliado
  /// tenía que pedir un OTP en cada arranque aunque su sesión estuviera activa
  /// — la app de usuarios sí hacía esta comprobación.
  Future<void> _resolverDestino() async {
    if (!mounted) return;

    Widget destino = const LoginScreen();

    try {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      await sessionService.initialize();

      final email = sessionService.userEmail;

      if (AuthStore.hasToken && email != null && email.isNotEmpty) {
        final check = await sessionService.checkSession(email);

        if (check['success'] == true && check['requires_verification'] == false) {
          // El aliado puede estar a mitad del registro: el enrutado decide si
          // le toca el home, el KYC, el perfil o el primer servicio.
          if (!mounted) return;
          destino = await AllyRouting.resolveDestination(email, onLogin: true);
        } else {
          // El servidor cerró la sesión (otro dispositivo, inactividad).
          await sessionService.clearAllSessionData();
        }
      }
    } catch (e) {
      debugPrint('No se pudo resolver la sesión guardada: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destino,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wordmarkSize = (size.width * 0.38).clamp(60.0, 240.0);
    final subtitleSize = (size.width * 0.095).clamp(24.0, 54.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: _bgColor,
        child: AnimatedBuilder(
          animation: Listenable.merge([_mainController, _shimmerController]),
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Emblema: el casco del icono de la app ────────────────
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kAzulAliado.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.engineering,
                          size: 52, color: kAzulAliado),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── Brand wordmark: "Tu" / "Du" + subtitle ───────────────
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'TitanOne',
                            fontSize: wordmarkSize,
                            fontWeight: FontWeight.bold,
                            color: _brandColor,
                            height: 0.85,
                          ),
                        ),
                        Text(
                          'Du',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'TitanOne',
                            fontSize: wordmarkSize,
                            fontWeight: FontWeight.bold,
                            color: _brandColor,
                            height: 0.85,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('allies'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'TitanOne',
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black45,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Shimmer accent line ──────────────────────────────────
                Opacity(
                  opacity: _taglineFadeAnimation.value,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: size.width * 0.40,
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: kAzulAliado.withOpacity(0.25)),
                          FractionallySizedBox(
                            alignment: Alignment(
                                _shimmerAnimation.value.clamp(-1.0, 1.0), 0),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    kAzulAliado.withOpacity(0.0),
                                    kAzulAliado,
                                    kAzulAliado.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Tagline ──────────────────────────────────────────────
                Opacity(
                  opacity: _taglineFadeAnimation.value,
                  child: Text(context.tr('onboarding_tagline'),
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 14,
                      color: kAzulAliado,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
