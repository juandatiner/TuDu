import 'package:flutter/material.dart';
import 'dart:async';
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

    // Scale: soft spring entrance
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    // Opacity for the brand wordmark
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Tagline fades in after the wordmark
    _taglineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Shimmer sweep on the accent line
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _mainController.forward().then((_) {
      _shimmerController.repeat();
    });

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
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
    final wordmarkSize = (size.width * 0.58).clamp(80.0, 380.0);

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
                // ── Brand wordmark: "Tu" stacked over "Du" ───────────────
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

                const SizedBox(height: 20),

                // ── Tagline ──────────────────────────────────────────────
                Opacity(
                  opacity: _taglineFadeAnimation.value,
                  child: const Text(
                    'Todo lo que necesitas, aquí.',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 15,
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
