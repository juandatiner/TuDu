import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
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
  final TextEditingController _nombreComercialController = TextEditingController();
  final TextEditingController _frasePresentacionController = TextEditingController();
  final TextEditingController _resumenController = TextEditingController();
  final TextEditingController _nuevoServicioController = TextEditingController();

  // Estado
  List<Map<String, dynamic>> _serviciosDisponibles = [];
  List<Map<String, dynamic>> _serviciosFiltrados = [];
  Map<String, dynamic>? _servicioSeleccionado;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _mostrandoNuevo = false;

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
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/services'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> servicesJson = data['services'] ?? [];
        setState(() {
          _serviciosDisponibles = servicesJson.cast<Map<String, dynamic>>();
          _serviciosFiltrados = List.from(_serviciosDisponibles);
        });
      }
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
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/services'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': nombre}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nuevoServicio = {
          'id': data['id'],
          'name': nombre,
        };
        setState(() {
          _serviciosDisponibles.add(nuevoServicio);
          _servicioSeleccionado = nuevoServicio;
          _searchController.text = nombre;
          _serviciosFiltrados = [];
          _nuevoServicioController.clear();
        });
        _showSnack('Servicio "$nombre" creado exitosamente');
      } else {
        _showSnack('Error creando el servicio', isError: true);
      }
    } catch (e) {
      _showSnack('Error de conexión', isError: true);
    }
  }

  Future<void> _guardarYContinuar() async {
    if (_servicioSeleccionado == null) {
      _showSnack('Por favor selecciona o crea un servicio');
      return;
    }
    if (_nombreComercialController.text.trim().isEmpty) {
      _showSnack('Ingresa tu nombre comercial');
      return;
    }
    if (_frasePresentacionController.text.trim().isEmpty) {
      _showSnack('Escribe una frase corta de presentación');
      return;
    }
    if (_resumenController.text.trim().isEmpty) {
      _showSnack('Escribe un resumen de lo que ofreces');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await http
          .post(
            Uri.parse('${Config.baseUrl}/ally-service-profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': widget.email,
              'service_id': _servicioSeleccionado!['id'],
              'nombre_comercial': _nombreComercialController.text.trim(),
              'frase_presentacion': _frasePresentacionController.text.trim(),
              'resumen': _resumenController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      // Registrar sesión del aliado (nuevo dispositivo o recién registrado)
      final sessionService = Provider.of<SessionService>(context, listen: false);
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
              const Text(
                'Tu servicio estrella',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Define el primer servicio con el que aparecerás en la plataforma.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ─── Selección de categoría de servicio ──────────────────────────
              const Text(
                'Categoría del servicio',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                decoration: InputDecoration(
                  hintText: 'Busca tu tipo de servicio...',
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: Colors.black.withOpacity(0.4)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.black.withOpacity(0.4)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _servicioSeleccionado = null);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brandColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
              else if (_serviciosFiltrados.isNotEmpty && _servicioSeleccionado == null)
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
                        leading: Icon(Icons.work_outline, color: _brandColor, size: 20),
                        title: Text(
                          s['name'],
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        onTap: () => setState(() {
                          _servicioSeleccionado = s;
                          _searchController.text = s['name'];
                          _serviciosFiltrados = [];
                        }),
                      );
                    },
                  ),
                ),

              // Opción de crear nuevo servicio
              if (_mostrandoNuevo || _serviciosFiltrados.isEmpty && _searchController.text.isNotEmpty && _servicioSeleccionado == null)
                _buildCrearNuevoServicio(),

              const SizedBox(height: 24),

              // ─── Nombre comercial ─────────────────────────────────────
              const Text(
                'Tu nombre o nombre de negocio',
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
                decoration: _inputDeco(
                  'Nombre comercial',
                  hint: 'Ej: Juan López / Electricidad López',
                ),
              ),
              const SizedBox(height: 20),

              // ─── Frase de presentación ────────────────────────────────
              const Text(
                'Frase de presentación',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Muy corta: di en una línea qué haces.',
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _frasePresentacionController,
                maxLength: 80,
                decoration: _inputDeco(
                  'Frase corta',
                  hint: 'Ej: Especialista en instalaciones eléctricas residenciales',
                ),
              ),
              const SizedBox(height: 20),

              // ─── Resumen del perfil ───────────────────────────────────
              const Text(
                'Resumen de tu experiencia',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Describe brevemente tus habilidades en este servicio. Este texto aparecerá en tu perfil.',
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45), height: 1.4),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _resumenController,
                maxLength: 400,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDeco(
                  'Resumen profesional',
                  hint: 'Cuéntanos qué sabes hacer, tu experiencia, y por qué los clientes deben elegirte...',
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
                    const Icon(Icons.lightbulb_outline, color: Color(0xFFF57F17), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '💡 Recuerda: más adelante podrás crear más servicios. Enfócate en este servicio únicamente.',
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

              const SizedBox(height: 36),

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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '¡Comenzar como Aliado!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  const Text(
                    'No encontré mi servicio',
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
                  'Nombre del nuevo servicio',
                  hint: 'Ej: Carpintería a domicilio',
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
                  child: const Text(
                    'Crear este servicio',
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
            _stepLabel('Datos', step >= 1),
            _stepLabel('Verificación', step >= 2),
            _stepLabel('Servicio', step >= 3),
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
