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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final Color _backgroundColor = Color(0xFFF4F2F2);
  final Color _textColor = Color(0xFF78BF32);

  @override
  void initState() {
    super.initState();

    // Controlador optimizado para animación rápida y fluida
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación de escala suave (Netflix style)
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ));

    // Animación de fade in para un efecto más profesional
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Iniciar animación
    _controller.forward();

    // Navegación optimizada - tiempo justo para la animación
    Timer(const Duration(milliseconds: 1500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Fuente responsiva optimizada para rendimiento
    final tuduFontSize = (screenWidth * 0.5).clamp(80.0, 350.0);
    final alliesFontSize = (screenWidth * 0.15).clamp(40.0, 80.0);

    return Scaffold(
      body: Container(
        color: _backgroundColor,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'To Do',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'TitanOne',
                          fontSize: tuduFontSize,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Aliados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'TitanOne',
                          fontSize: alliesFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
