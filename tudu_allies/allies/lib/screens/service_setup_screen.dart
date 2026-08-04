import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../widgets/validacion_formulario.dart';
import '../services/ally_api.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import 'home_screen.dart';

class ServiceSetupScreen extends StatefulWidget {
  final String email;

  const ServiceSetupScreen({super.key, required this.email});

  @override
  State<ServiceSetupScreen> createState() => _ServiceSetupScreenState();
}

class _ServiceSetupScreenState extends State<ServiceSetupScreen> {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  // Controladores de texto
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nombreComercialController =
      TextEditingController();
  final TextEditingController _frasePresentacionController =
      TextEditingController();
  final TextEditingController _resumenController = TextEditingController();
  final TextEditingController _nuevoServicioController =
      TextEditingController();

  // Estado
  List<Map<String, dynamic>> _serviciosDisponibles = [];
  List<Map<String, dynamic>> _serviciosFiltrados = [];
  Map<String, dynamic>? _servicioSeleccionado;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _mostrandoNuevo = false;

  // Un motivo por campo + el aviso general del formulario.
  String? _errorServicio;
  String? _errorNombreComercial;
  String? _errorFrase;
  String? _errorResumen;
  String? _avisoGeneral;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    _searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterServices);
    _searchController.dispose();
    _nombreComercialController.dispose();
    _frasePresentacionController.dispose();
    _resumenController.dispose();
    _nuevoServicioController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final servicios = await ServicioApi.catalogo();
      setState(() {
        _serviciosDisponibles = servicios;
        _serviciosFiltrados = List.from(_serviciosDisponibles);
      });
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _serviciosFiltrados = List.from(_serviciosDisponibles);
        _mostrandoNuevo = false;
      } else {
        _serviciosFiltrados = _serviciosDisponibles
            .where((s) => (s['name'] as String).toLowerCase().contains(query))
            .toList();
        _mostrandoNuevo = _serviciosFiltrados.isEmpty && query.isNotEmpty;
      }
    });
  }

  Future<void> _crearNuevoServicio() async {
    final nombre = _nuevoServicioController.text.trim();
    if (nombre.isEmpty) return;

    try {
      final data = await Api.post('/services', {'name': nombre});

      if (!mounted) return;

      {
        final nuevoServicio = <String, dynamic>{
          'id': (data as Map)['id'],
          'name': nombre,
        };
        setState(() {
          _serviciosDisponibles.add(nuevoServicio);
          _servicioSeleccionado = nuevoServicio;
          _errorServicio = null;
          _searchController.text = nombre;
          _serviciosFiltrados = [];
          _nuevoServicioController.clear();
        });
        _showSnack('Servicio "$nombre" creado exitosamente');
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(context.tr('connection_error'), isError: true);
    }
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorServicio == null &&
        _errorNombreComercial == null &&
        _errorFrase == null &&
        _errorResumen == null) {
      _avisoGeneral = null;
    }
  }

  Future<void> _guardarYContinuar() async {
    // Todo se revisa de una sola pasada: lo que falte queda marcado en rojo.
    final errorServicio = _servicioSeleccionado == null
        ? context.tr('select_or_create_service')
        : null;
    final errorNombre = _nombreComercialController.text.trim().isEmpty
        ? Validacion.requerido
        : null;
    final errorFrase = _frasePresentacionController.text.trim().isEmpty
        ? Validacion.requerido
        : null;
    final errorResumen =
        _resumenController.text.trim().isEmpty ? Validacion.requerido : null;

    final hayErrores = errorServicio != null ||
        errorNombre != null ||
        errorFrase != null ||
        errorResumen != null;

    setState(() {
      _errorServicio = errorServicio;
      _errorNombreComercial = errorNombre;
      _errorFrase = errorFrase;
      _errorResumen = errorResumen;
      _avisoGeneral = hayErrores ? Validacion.textoCamposFaltantes : null;
    });

    if (hayErrores) return;

    setState(() => _isSaving = true);

    try {
      await AliadoApi.crearPerfilServicio({
        'email': widget.email,
        'service_id': _servicioSeleccionado!['id'],
        'nombre_comercial': _nombreComercialController.text.trim(),
        'frase_presentacion': _frasePresentacionController.text.trim(),
        'resumen': _resumenController.text.trim(),
      });

      if (!mounted) return;

      // Registrar sesión del aliado (nuevo dispositivo o recién registrado)
      final sessionService =
          Provider.of<SessionService>(context, listen: false);
      await sessionService.registerSession(widget.email);

      // Sea exitoso o no, navegar al home
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AllyHomeScreen(allyEmail: widget.email),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } catch (e) {
      // Navegar al home de todas formas
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AllyHomeScreen(allyEmail: widget.email),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _brandColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(0.35),
        fontSize: 13,
      ),
      labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Logo + progreso
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tu',
                    style: const TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 36,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                  Text(
                    'Du',
                    style: const TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 36,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildProgressIndicator(step: 3),
              const SizedBox(height: 28),

              // Título
              Text(
                context.tr('your_star_service'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('service_setup_intro'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ─── Selección de categoría de servicio ──────────────────────────
              Text(
                context.tr('service_category'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Chip de seleccionado
              if (_servicioSeleccionado != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _brandColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: _brandColor, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _servicioSeleccionado!['name'],
                          style: TextStyle(
                            color: _brandColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _servicioSeleccionado = null;
                          _searchController.clear();
                        }),
                        child: Icon(Icons.close, color: _brandColor, size: 18),
                      ),
                    ],
                  ),
                ),

              // Barra de búsqueda
              TextField(
                controller: _searchController,
                decoration: Validacion.decorar(
                  InputDecoration(
                    hintText: context.tr('search_service_hint'),
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.black.withOpacity(0.4)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.black.withOpacity(0.4)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _servicioSeleccionado = null;
                                _errorServicio = null;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.black.withOpacity(0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.black.withOpacity(0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _brandColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  error: _errorServicio,
                ),
              ),
              const SizedBox(height: 8),

              // Lista de servicios filtrados
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _brandColor),
                  ),
                )
              else if (_serviciosFiltrados.isNotEmpty &&
                  _servicioSeleccionado == null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _serviciosFiltrados.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.black.withOpacity(0.07),
                    ),
                    itemBuilder: (_, i) {
                      final s = _serviciosFiltrados[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.work_outline,
                            color: _brandColor, size: 20),
                        title: Text(
                          s['name'],
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                        onTap: () => setState(() {
                          _servicioSeleccionado = s;
                          _errorServicio = null;
                          _revisarAviso();
                          _searchController.text = s['name'];
                          _serviciosFiltrados = [];
                        }),
                      );
                    },
                  ),
                ),

              // Opción de crear nuevo servicio
              if (_mostrandoNuevo ||
                  _serviciosFiltrados.isEmpty &&
                      _searchController.text.isNotEmpty &&
                      _servicioSeleccionado == null)
                _buildCrearNuevoServicio(),

              const SizedBox(height: 24),

              // ─── Nombre comercial ─────────────────────────────────────
              Text(
                context.tr('your_business_name'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreComercialController,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {
                  _errorNombreComercial = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(
                    context.tr('commercial_name'),
                    hint: context.tr('commercial_name_hint'),
                  ),
                  error: _errorNombreComercial,
                ),
              ),
              const SizedBox(height: 20),

              // ─── Frase de presentación ────────────────────────────────
              Text(
                context.tr('pitch_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('pitch_help'),
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.45)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _frasePresentacionController,
                maxLength: 80,
                onChanged: (_) => setState(() {
                  _errorFrase = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(
                    context.tr('pitch_label'),
                    hint: context.tr('pitch_hint'),
                  ),
                  error: _errorFrase,
                ),
              ),
              const SizedBox(height: 20),

              // ─── Resumen del perfil ───────────────────────────────────
              Text(
                context.tr('summary_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('summary_help'),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.45),
                    height: 1.4),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _resumenController,
                maxLength: 400,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {
                  _errorResumen = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(
                    context.tr('summary_label'),
                    hint: context.tr('summary_hint'),
                  ),
                  error: _errorResumen,
                ),
              ),

              // Aviso informativo
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Color(0xFFF57F17), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('service_setup_tip'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Validacion.aviso(_avisoGeneral),

              // Botón final
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarYContinuar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          context.tr('start_as_ally'),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildCrearNuevoServicio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle_outline, color: _brandColor),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('service_not_found'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nuevoServicioController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco(
                  context.tr('new_service_name'),
                  hint: context.tr('new_service_hint'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _crearNuevoServicio,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _brandColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    context.tr('create_this_service'),
                    style: TextStyle(
                      color: _brandColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
                        color: completed || active
                            ? _brandColor
                            : Colors.black.withOpacity(0.15),
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
