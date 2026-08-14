import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_api.dart';
import '../services/session_service.dart';
import 'registration_screen.dart';
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
    // Recién registrado: la fila ya existe, así que la sesión se puede guardar
    // y de acá se pasa a la app.
    if (widget.isAfterRegistration) {
      await _registrarSesion();
      _irA(() => HomeScreen(userEmail: widget.email));
      return;
    }

    // Viene del código del correo. Si la cuenta ya existe se abre la sesión y
    // entra; si no, esta pantalla es solo el "verificación exitosa" antes del
    // formulario — la sesión no se puede registrar todavía porque la fila del
    // usuario aún no existe.
    bool existe;
    try {
      existe = await AuthApi.existeUsuario(widget.email);
    } catch (e) {
      existe = false;
    }

    if (!mounted) return;

    if (existe) {
      await _registrarSesion();
      _irA(() => HomeScreen(userEmail: widget.email));
    } else {
      _irA(() => RegistrationScreen(email: widget.email));
    }
  }

  Future<void> _registrarSesion() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.registerSession(widget.email);
  }

  /// Deja el visto verde en pantalla el tiempo suficiente para leerlo.
  void _irA(Widget Function() destino) {
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino()),
      );
    });
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
                Text(context.tr('verification_success_title'),
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
