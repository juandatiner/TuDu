import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ally_api.dart';
import '../services/ally_routing.dart';
import '../services/session_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Estado del LoginScreen
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: kDebugMode ? 'cosmodavid2009@gmail.com' : '',
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.initialize();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF78BF32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Verificar que el campo de email tenga contenido
      if (_emailController.text.isEmpty) {
        _showSnack('Por favor ingresa tu correo electrónico');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final sessionService =
            Provider.of<SessionService>(context, listen: false);

        // Verificar si el dispositivo necesita verificación
        final sessionCheck =
            await sessionService.checkSession(_emailController.text);

        if (sessionCheck['success'] == true &&
            sessionCheck['requires_verification'] == false) {
          // La sesión está activa, no necesita verificación
          // Guardar el email y navegar directamente al home
          await sessionService.setUserEmail(_emailController.text);

          // No entrar directo al home: el aliado puede tener sesión válida y aun
          // así estar sin KYC. El enrutador decide el paso que le falta.
          final destino = await AllyRouting.resolveDestination(
              _emailController.text,
              onLogin: true);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => destino),
            );
          }
        } else {
          // Necesita verificación, enviar OTP y navegar a la pantalla OTP
          await AuthApi.enviarCodigo(_emailController.text);

          if (mounted) {
            // Navegar a la pantalla OTP
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpScreen(email: _emailController.text),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          debugPrint('Error de conexión detallado: $e');
          _showSnack('Error de conexión. Verifica tu conexión a internet.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Mostrar mensaje si la validación falla
      _showSnack('Ingresa un correo electrónico válido para continuar');
    }
  }

  void _loginWithGoogle() {
    // Implementar login con Google
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login con Google - Próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _loginWithFacebook() {
    // Implementar login con Facebook
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login con Facebook - Próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Logo/Title
                  Column(
                    children: [
                      Text(
                        'Tu',
                        style: TextStyle(
                          fontFamily: 'TitanOne',
                          fontSize: 90,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF78BF32),
                          height: 0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Du',
                        style: TextStyle(
                          fontFamily: 'TitanOne',
                          fontSize: 90,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF78BF32),
                          height: 0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Ingresa tu correo electrónico',
                      labelStyle:
                          TextStyle(color: Colors.black.withOpacity(0.7)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.black.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.black.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      errorStyle: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Dejar que el SnackBar maneje este caso
                      }
                      // Validación básica de email
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9@._-]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF78BF32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Separator
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.black.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ó',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.black.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Social Login Buttons
                  ElevatedButton.icon(
                    onPressed: _loginWithGoogle,
                    icon: Image.asset(
                      'assets/images/logos/google_logo.png',
                      height: 24,
                      width: 24,
                    ),
                    label: const Text('Continuar con Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF595959),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _loginWithFacebook,
                    icon: Image.asset(
                      'assets/images/logos/facebook_logo.png',
                      height: 24,
                      width: 24,
                    ),
                    label: const Text('Continuar con Facebook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF595959),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
