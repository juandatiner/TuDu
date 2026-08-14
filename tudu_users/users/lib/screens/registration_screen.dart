import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_api.dart';
import '../widgets/contador_campo.dart';
import '../widgets/validacion_formulario.dart';
import 'kyc_verification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String email;

  const RegistrationScreen({super.key, required this.email});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  DateTime? _fechaNacimiento;
  bool _isLoading = false;

  static const Color _brandColor = Color(0xFF78BF32);

  // El contador de cada campo se ve solo mientras se escribe ahí.
  final _focoNombre = FocusNode();
  final _focoApellido = FocusNode();

  // Un error por campo + el aviso general: se revisan todos de una, no de a uno.
  String? _errorNombre;
  String? _errorApellido;
  String? _errorFecha;
  String? _avisoGeneral;

  @override
  void initState() {
    super.initState();
    for (final f in [_focoNombre, _focoApellido]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _focoNombre.dispose();
    _focoApellido.dispose();
    super.dispose();
  }

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

    // La edad se comprueba también acá y no solo en el selector: el campo
    // puede quedar vacío si nunca lo abrieron.
    String? fecha;
    if (_fechaNacimiento == null) {
      fecha = requerido;
    } else if (!_esMayorDeEdad(_fechaNacimiento!)) {
      fecha = context.tr('must_be_18_to_use');
    }

    setState(() {
      _errorNombre = nombre;
      _errorApellido = apellido;
      _errorFecha = fecha;
      _avisoGeneral = (nombre == null && apellido == null && fecha == null)
          ? null
          : Validacion.textoCamposFaltantes(context);
    });

    return nombre == null && apellido == null && fecha == null;
  }

  /// 18 años cumplidos a día de hoy.
  bool _esMayorDeEdad(DateTime fecha) {
    final hoy = DateTime.now();
    final edad = hoy.year -
        fecha.year -
        ((hoy.month > fecha.month ||
                (hoy.month == fecha.month && hoy.day >= fecha.day))
            ? 0
            : 1);
    return edad >= 18;
  }

  /// Campo con el borde según su estado: rojo si hay error, verde si ya cumple.
  /// Mismo formato que el registro del aliado: ícono verde a la izquierda.
  InputDecoration _decoracion(String etiqueta,
      {String? error, IconData? icono}) {
    return Validacion.decorar(
      InputDecoration(
        labelText: etiqueta,
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
        prefixIcon:
            icono != null ? Icon(icono, color: _brandColor, size: 20) : null,
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
          borderSide: const BorderSide(color: _brandColor, width: 2),
        ),
        counterText: '',
      ),
      error: error,
    );
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorNombre == null && _errorApellido == null && _errorFecha == null) {
      _avisoGeneral = null;
    }
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
        fechaNacimiento: _fechaNacimiento!.toIso8601String().split('T')[0],
      );

        // Paso 2: la verificación de identidad. La cuenta existe pero todavía
        // no está verificada; eso lo decide el admin cuando revisa los
        // documentos.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => KycVerificationScreen(email: widget.email),
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
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                const SizedBox(height: 20),

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
                const SizedBox(height: 32),

                // Indicador de progreso: acá son dos pasos, no tres como en la
                // app de aliados — el cliente no sube documentos ni crea un
                // servicio, solo deja sus datos y queda verificado.
                _buildProgressIndicator(step: 1),
                const SizedBox(height: 28),

                // Título
                Text(context.tr('personal_data'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('tell_us_about_you'),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Campo Nombre
                TextField(
                  controller: _nombreController,
                  focusNode: _focoNombre,
                  maxLength: 20,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {
                    _errorNombre = null;
                    _revisarAviso();
                  }),
                  decoration: _decoracion(
                    context.tr('name'),
                    error: _errorNombre,
                    icono: Icons.person_outline,
                  ),
                ),
                ContadorCampo(
                  controller: _nombreController,
                  foco: _focoNombre,
                  maxLength: 20,
                ),
                const SizedBox(height: 16),

                // Campo Apellido
                TextField(
                  controller: _apellidoController,
                  focusNode: _focoApellido,
                  maxLength: 20,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {
                    _errorApellido = null;
                    _revisarAviso();
                  }),
                  decoration: _decoracion(
                    context.tr('last_name'),
                    error: _errorApellido,
                    icono: Icons.person_outline,
                  ),
                ),
                ContadorCampo(
                  controller: _apellidoController,
                  foco: _focoApellido,
                  maxLength: 20,
                ),
                const SizedBox(height: 16),

                // Selector de fecha de nacimiento
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _errorFecha != null
                            ? Validacion.colorError
                            : _fechaNacimiento != null
                                ? _brandColor
                                : Colors.black.withOpacity(0.3),
                        width: (_errorFecha != null || _fechaNacimiento != null)
                            ? 2
                            : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: _brandColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fechaNacimiento != null
                                ? _formatearFecha(_fechaNacimiento!)
                                : context.tr('birth_date'),
                            style: TextStyle(
                              fontSize: 16,
                              color: _fechaNacimiento != null
                                  ? Colors.black87
                                  : Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.black.withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
                Validacion.mensajeCampo(_errorFecha),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    context.tr('must_be_18'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                Validacion.aviso(context, _avisoGeneral),

                // Botón Continuar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
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
                        : Text(context.tr('continue_button'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra de pasos, igual que la del registro del aliado pero con dos tramos:
  /// aquí solo hay datos y verificación.
  Widget _buildProgressIndicator({required int step}) {
    return Column(
      children: [
        Row(
          children: List.generate(2, (i) {
            final activo = i + 1 <= step;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: activo
                            ? _brandColor
                            : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 1) const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stepLabel(context.tr('step_data'), step >= 1),
            _stepLabel(context.tr('step_verification'), step >= 2),
          ],
        ),
      ],
    );
  }

  Widget _stepLabel(String label, bool activo) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
        color: activo ? _brandColor : Colors.black.withOpacity(0.4),
      ),
    );
  }

  /// Selector de fecha, igual que en el registro del aliado: rueda de iOS en
  /// una hoja con el fondo difuminado y tope en la fecha de los 18 años.
  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final maxima = DateTime(hoy.year - 18, hoy.month, hoy.day);
    DateTime elegida = _fechaNacimiento ?? DateTime(hoy.year - 25);
    String? errorHoja;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          context.tr('birth_date'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('must_be_18'),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: elegida,
                      minimumDate: DateTime(1900, 1, 1),
                      maximumDate: maxima,
                      onDateTimeChanged: (nueva) {
                        elegida = nueva;
                        errorHoja = null;
                      },
                    ),
                  ),
                  if (errorHoja != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        errorHoja!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          // La rueda ya topa en los 18 años, pero se revisa
                          // igual: es el dato que decide si puede usar la app.
                          if (!_esMayorDeEdad(elegida)) {
                            setModalState(() {
                              errorHoja = context.tr('must_be_18_to_use');
                            });
                            return;
                          }

                          setState(() {
                            _fechaNacimiento = elegida;
                            _errorFecha = null;
                            _revisarAviso();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(context.tr('confirm'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
