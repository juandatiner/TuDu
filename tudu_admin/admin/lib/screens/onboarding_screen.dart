import 'package:flutter/material.dart';
import 'dart:async';

import '../services/admin_api.dart';
import '../services/api.dart';
import '../services/auth_store.dart';
import 'dashboard_screen.dart';
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

  /// Pizarra del icono del panel: lo distingue de las apps de cliente y aliado.
  static const Color _pizarra = Color(0xFF1F2A44);

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

  /// Con un token guardado y todavía válido se entra directo al panel. Antes se
  /// mandaba siempre al login, así que había que escribir usuario y contraseña
  /// en cada arranque aunque la sesión siguiera viva.
  Future<void> _resolverDestino() async {
    Widget destino = const LoginScreen();

    if (AuthStore.hasToken) {
      try {
        // Una llamada real: es la única forma de saber si el token sigue
        // sirviendo. Si expiró, `Api` intenta refrescarlo solo y, si tampoco,
        // responde 401 y se cae al login.
        await AdminsApi.listar();
        destino = const DashboardScreen();
      } on ApiException catch (e) {
        if (!e.esSesionInvalida) destino = const DashboardScreen();
      } catch (_) {
        // Sin red no se puede confirmar: mejor el login que un panel vacío.
      }
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
                // ── Emblema: el escudo del icono del panel ───────────────
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _pizarra.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user,
                          size: 52, color: _pizarra),
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
                          'Admin',
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
                      width: size.width * 0.35,
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: _brandColor.withOpacity(0.25)),
                          FractionallySizedBox(
                            alignment: Alignment(
                                _shimmerAnimation.value.clamp(-1.0, 1.0), 0),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _brandColor.withOpacity(0.0),
                                    _brandColor,
                                    _brandColor.withOpacity(0.0),
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
                  child: const Text(
                    'Panel de control.',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 14,
                      color: Color(0xFF78BF32),
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
