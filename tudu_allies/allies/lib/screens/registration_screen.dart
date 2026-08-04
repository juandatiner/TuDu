import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../widgets/validacion_formulario.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../services/api.dart';
import '../services/ally_api.dart';
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

  // Un motivo por campo + el aviso general del formulario.
  String? _errorNombre;
  String? _errorApellido;
  String? _errorFecha;
  String? _avisoGeneral;
  bool _isLoading = false;

  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
      prefixIcon: icon != null ? Icon(icon, color: _brandColor, size: 20) : null,
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
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    DateTime? tempBirthDate = _fechaNacimiento ?? DateTime(now.year - 25);
    String? tempError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
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
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Título
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            context.tr('birth_date'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            context.tr('must_be_18_short'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempBirthDate,
                        minimumDate: DateTime(1900, 1, 1),
                        maximumDate: maxDate,
                        onDateTimeChanged: (DateTime newDate) {
                          tempBirthDate = newDate;
                          tempError = null;
                        },
                      ),
                    ),
                    if (tempError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          tempError!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            // Verificar edad manualmente por si acaso
                            final age = now.year - tempBirthDate!.year -
                                (now.month > tempBirthDate!.month ||
                                        (now.month == tempBirthDate!.month && now.day >= tempBirthDate!.day)
                                    ? 0 : 1);

                            if (age < 18) {
                              setModalState(() {
                                tempError = context.tr('must_be_18_short');
                              });
                              return;
                            }

                            setState(() {
                              _fechaNacimiento = tempBirthDate;
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorNombre == null && _errorApellido == null && _errorFecha == null) {
      _avisoGeneral = null;
    }
  }

  Future<void> _continuar() async {
    // Se revisa todo de una: lo que falte queda marcado en rojo.
    final errorNombre =
        _nombreController.text.trim().isEmpty ? Validacion.requerido : null;
    final errorApellido =
        _apellidoController.text.trim().isEmpty ? Validacion.requerido : null;
    final errorFecha = _fechaNacimiento == null ? Validacion.requerido : null;

    final hayErrores =
        errorNombre != null || errorApellido != null || errorFecha != null;

    setState(() {
      _errorNombre = errorNombre;
      _errorApellido = errorApellido;
      _errorFecha = errorFecha;
      _avisoGeneral = hayErrores ? Validacion.textoCamposFaltantes : null;
    });

    if (hayErrores) return;

    setState(() => _isLoading = true);

    try {
      await AliadoApi.registrar(
        email: widget.email,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        fechaNacimiento: _fechaNacimiento!.toIso8601String().split('T')[0],
      );

      if (!mounted) return;

      {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => KycVerificationScreen(email: widget.email),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(context.tr('connection_error_check'), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        backgroundColor: isError ? Colors.red : _brandColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
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
                      color: _brandColor,
                      height: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Du',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: _brandColor,
                      height: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Indicador de progreso
              _buildProgressIndicator(step: 1),
              const SizedBox(height: 28),

              // Título
              Text(context.tr('personal_data'),
                style: TextStyle(
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
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]")),
                ],
                onChanged: (_) => setState(() {
                  _errorNombre = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDecoration(context.tr('first_name'),
                      icon: Icons.person_outline),
                  error: _errorNombre,
                ),
              ),
              const SizedBox(height: 16),

              // Campo Apellido
              TextField(
                controller: _apellidoController,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]")),
                ],
                onChanged: (_) => setState(() {
                  _errorApellido = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDecoration(context.tr('last_name'),
                      icon: Icons.person_outline),
                  error: _errorApellido,
                ),
              ),
              const SizedBox(height: 16),

              // Selector de fecha de nacimiento
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorFecha != null
                          ? Validacion.colorError
                          : _fechaNacimiento != null
                              ? _brandColor
                              : Colors.black.withOpacity(0.3),
                      width: (_errorFecha != null || _fechaNacimiento != null) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: _fechaNacimiento != null ? _brandColor : Colors.black.withOpacity(0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fechaNacimiento != null
                              ? _formatDate(_fechaNacimiento!)
                              : context.tr('birth_date'),
                          style: TextStyle(
                            fontSize: 16,
                            color: _fechaNacimiento != null
                                ? Colors.black87
                                : Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black.withOpacity(0.4),
                      ),
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

              Validacion.aviso(_avisoGeneral),

              // Botón Continuar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _continuar,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(context.tr('continue_button'),
                          style: TextStyle(
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

  Widget _buildProgressIndicator({required int step}) {
    return Column(
      children: [
        Row(
          children: List.generate(3, (i) {
            final completed = i + 1 < step;
            final active = i + 1 == step;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: completed || active ? _brandColor : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 4),
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
            _stepLabel(context.tr('step_service'), step >= 3),
          ],
        ),
      ],
    );
  }

  Widget _stepLabel(String label, bool active) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        color: active ? _brandColor : Colors.black.withOpacity(0.4),
      ),
    );
  }
}
