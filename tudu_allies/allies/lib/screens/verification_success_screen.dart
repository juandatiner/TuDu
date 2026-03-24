import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../config.dart';
import '../services/session_service.dart';
import 'registration_screen.dart';
import 'kyc_verification_screen.dart';
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
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/check-ally'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': widget.email}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AllyHomeScreen(allyEmail: widget.email),
            ),
          );
        } else {
          // Si faltan datos personales o servicios
          if (data['partial'] == 'service') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    KycVerificationScreen(email: widget.email),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RegistrationScreen(email: widget.email),
              ),
            );
          }
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationScreen(email: widget.email),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrationScreen(email: widget.email),
        ),
      );
    }
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
                const Text(
                  '¡Verificación exitosa!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Redirigiendo...',
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
