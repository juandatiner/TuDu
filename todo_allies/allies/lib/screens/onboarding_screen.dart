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
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _backgroundAnimation;
  late Animation<Color?> _textAnimation;

  final Color _backgroundColor = Color(0xFFF4F2F2);
  final Color _textColor = Color(0xFF78BF32);

  @override
  void initState() {
    super.initState();

    // Configurar controlador de escala
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Animación de escala suave con fade in
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutQuart,
    ));

    // Configurar animaciones estáticas de color
    _backgroundAnimation = AlwaysStoppedAnimation<Color>(_backgroundColor);
    _textAnimation = AlwaysStoppedAnimation<Color>(_textColor);

    // Iniciar animación de escala
    _scaleController.forward();

    // Navegar automáticamente después de 2 segundos
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            color: _backgroundAnimation.value ?? Colors.blue,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100.0),
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: AnimatedBuilder(
                        animation: _textAnimation,
                        builder: (context, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'To Do',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'TitanOne',
                                  fontSize: 300,
                                  fontWeight: FontWeight.bold,
                                  color: _textAnimation.value ?? Colors.white,
                                  height: 1.0, // Espacio normal entre líneas
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Aliados',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'TitanOne',
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
