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

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();

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
    final tuduFontSize = (screenWidth * 0.5).clamp(80.0, 350.0);
    final adminFontSize = (screenWidth * 0.15).clamp(40.0, 80.0);

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
                        'Admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'TitanOne',
                          fontSize: adminFontSize,
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
