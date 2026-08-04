import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_api.dart';
import '../widgets/validacion_formulario.dart';
import 'verification_success_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String email;

  const RegistrationScreen({super.key, required this.email});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  bool _isLoading = false;

  // Un error por campo + el aviso general: se revisan todos de una, no de a uno.
  String? _errorNombre;
  String? _errorApellido;
  String? _avisoGeneral;

  bool _validar() {
    final requerido = Validacion.requerido(context);
    String? nombre;
    String? apellido;

    if (_nombreController.text.trim().isEmpty) {
      nombre = requerido;
    } else if (_nombreController.text.length > 20) {
      nombre = context.tr('max_20_chars');
    }

    if (_apellidoController.text.trim().isEmpty) {
      apellido = requerido;
    } else if (_apellidoController.text.length > 20) {
      apellido = context.tr('max_20_chars');
    }

    setState(() {
      _errorNombre = nombre;
      _errorApellido = apellido;
      _avisoGeneral = (nombre == null && apellido == null)
          ? null
          : Validacion.textoCamposFaltantes(context);
    });

    return nombre == null && apellido == null;
  }

  /// Campo con el borde según su estado: rojo si hay error, verde si ya cumple.
  InputDecoration _decoracion(String etiqueta,
      {String? error, bool ok = false}) {
    return Validacion.decorar(
      InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF78BF32), width: 2),
        ),
        counterText: '',
      ),
      error: error,
    );
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorNombre == null && _errorApellido == null) _avisoGeneral = null;
  }

  Future<void> _registerUser() async {
    if (!_validar()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApi.registrarUsuario(
        email: widget.email,
        nombre: _nombreController.text,
        apellido: _apellidoController.text,
      );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationSuccessScreen(
              email: widget.email,
              isAfterRegistration: true,
            ),
          ),
        );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('otp_connection_error')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF4F2F2),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Column(
                  children: [
                    Text(
                      'Tu',
                      style: TextStyle(
                        fontFamily: 'TitanOne',
                        fontSize: 60,
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
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF78BF32),
                        height: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Título
                Text(context.tr('complete_registration'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Campo Nombre
                TextField(
                  controller: _nombreController,
                  maxLength: 20,
                  onChanged: (_) => setState(() {
                    _errorNombre = null;
                    _revisarAviso();
                  }),
                  decoration: _decoracion(
                    context.tr('name'),
                    error: _errorNombre,
                  ),
                ),
                const SizedBox(height: 16),

                // Campo Apellido
                TextField(
                  controller: _apellidoController,
                  maxLength: 20,
                  onChanged: (_) => setState(() {
                    _errorApellido = null;
                    _revisarAviso();
                  }),
                  decoration: _decoracion(
                    context.tr('last_name'),
                    error: _errorApellido,
                  ),
                ),
                const SizedBox(height: 24),

                Validacion.aviso(context, _avisoGeneral),

                // Botón Registrar
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 48),
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
                      : Text(context.tr('register_button'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
