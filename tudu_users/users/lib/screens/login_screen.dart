import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_api.dart';
import '../widgets/validacion_formulario.dart';
import '../services/session_service.dart';
import 'otp_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Estado del LoginScreen
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Pre-llenado solo en debug para la cuenta de prueba
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

  // Aviso general del formulario.
  String? _avisoGeneral;

  bool get _correoValido => RegExp(r'^[^@]+@[^@]+\.[^@]+')
      .hasMatch(_emailController.text.trim());

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _avisoGeneral = null);
      // Verificar que el campo de email tenga contenido
      if (_emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('enter_email_prompt')),
            backgroundColor: Colors.red,
          ),
        );
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

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HomeScreen(userEmail: _emailController.text),
              ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('otp_connection_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // El campo ya queda marcado en rojo por el validator; abajo solo va el
      // aviso general, sin repetir de qué campo se trata.
      setState(() => _avisoGeneral = Validacion.textoCamposFaltantes(context));
    }
  }

  void _loginWithSocial(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider - ${context.tr('social_soon')}'),
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
                          color: Color(0xFF78BF32),
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
                          color: Color(0xFF78BF32),
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
                    onChanged: (_) => setState(() {
                      // El aviso desaparece en cuanto el campo deja de estar mal.
                      if (_avisoGeneral != null &&
                          (_formKey.currentState?.validate() ?? false)) {
                        _avisoGeneral = null;
                      }
                    }),
                    decoration: Validacion.decorar(
                      InputDecoration(
                      labelText: context.tr('enter_email_prompt'),
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
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      errorStyle: const TextStyle(
                        color: Validacion.colorError,
                        fontSize: 14,
                      ),
                      ),
                      // Verde solo cuando el correo ya es válido; el rojo del
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return context.tr('invalid_email');
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9@._-]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Validacion.aviso(context, _avisoGeneral),

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
                    onPressed: () => _loginWithSocial('Google'),
                    icon: Image.asset(
                      'assets/images/logos/google_logo.png',
                      height: 24,
                      width: 24,
                    ),
                    label: Text(context.tr('continue_google')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF595959),
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
                    onPressed: () => _loginWithSocial('Facebook'),
                    icon: Image.asset(
                      'assets/images/logos/facebook_logo.png',
                      height: 24,
                      width: 24,
                    ),
                    label: Text(context.tr('continue_facebook')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF595959),
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
