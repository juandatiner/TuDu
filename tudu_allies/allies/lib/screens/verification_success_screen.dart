import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/ally_routing.dart';
import '../services/session_service.dart';
import 'home_screen.dart';

class VerificationSuccessScreen extends StatefulWidget {
  final String email;
  final bool isAfterRegistration;

  const VerificationSuccessScreen({
    super.key,
    required this.email,
    this.isAfterRegistration = false,
  });

  @override
  State<VerificationSuccessScreen> createState() =>
      _VerificationSuccessScreenState();
}

class _VerificationSuccessScreenState extends State<VerificationSuccessScreen> {
  @override
  void initState() {
    super.initState();
    _registerSessionAndNavigate();
  }

  Future<void> _registerSessionAndNavigate() async {
    // Registrar la sesión del dispositivo
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.registerSession(widget.email);

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (widget.isAfterRegistration) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AllyHomeScreen(allyEmail: widget.email),
          ),
        );
      } else {
        _checkAlly();
      }
    });
  }

  Future<void> _checkAlly() async {
    final destino =
        await AllyRouting.resolveDestination(widget.email, onLogin: true);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF4F2F2),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tu',
                  style: TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78BF32),
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Du',
                  style: TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78BF32),
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 40),
                const Icon(
                  Icons.check_circle,
                  size: 100,
                  color: Color(0xFF78BF32),
                ),
                const SizedBox(height: 20),
                Text(context.tr('verification_success'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(context.tr('redirecting'),
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
