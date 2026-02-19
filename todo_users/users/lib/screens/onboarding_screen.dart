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
    // Calcular tamaño de fuente responsivo basado en el tamaño de la pantalla
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // El texto "To\nDo" (dos líneas) debe caber en la pantalla con márgenes seguros
    // Calculamos el tamaño basado en el ancho para que cada letra quepa
    // y consideramos que son 2 líneas con espacio entre ellas
    // El factor 0.7 para el ancho permite que "To" o "Do" quepan con margen
    // y el texto se vea grande y prominente
    final responsiveFontSize = (screenWidth * 0.7).clamp(100.0, 500.0);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _backgroundAnimation.value ?? Colors.blue,
                  (_backgroundAnimation.value ?? Colors.blue).withOpacity(0.7),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: AnimatedBuilder(
                        animation: _textAnimation,
                        builder: (context, child) {
                          return FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              'To\nDo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'TitanOne',
                                fontSize: responsiveFontSize,
                                fontWeight: FontWeight.bold,
                                color: _textAnimation.value ?? Colors.white,
                                height: 0.9,
                              ),
                            ),
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
