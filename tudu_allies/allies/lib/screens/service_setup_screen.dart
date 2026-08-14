import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../widgets/validacion_formulario.dart';
import '../widgets/camera_capture_mixin.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../services/ally_routing.dart';

class ServiceSetupScreen extends StatefulWidget {
  final String email;

  /// true solo cuando el aliado entra por "Agregar" desde Mis Servicios
  /// (ya tiene cuenta activa). En el onboarding (primer servicio, paso
  /// obligatorio tras el KYC) esto es false: no hay a dónde volver ni
  /// soporte que ofrecer todavía, así que no se muestran esos controles.
  final bool esOpcional;

  const ServiceSetupScreen({
    super.key,
    required this.email,
    this.esOpcional = false,
  });

  @override
  State<ServiceSetupScreen> createState() => _ServiceSetupScreenState();
}

class _ServiceSetupScreenState extends State<ServiceSetupScreen>
    with CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  // Controladores de texto
  final TextEditingController _categoriaSearchController =
      TextEditingController();
  final TextEditingController _nuevaCategoriaController =
      TextEditingController();
  final TextEditingController _nuevoServicioNombreController =
      TextEditingController();
  // El contador solo se ve mientras se escribe ese campo.
  final _focoServicioNombre = FocusNode();
  final _focoServicioDescripcion = FocusNode();

  final TextEditingController _nuevoServicioDescripcionController =
      TextEditingController();

  // Categoría
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _categoriasFiltradas = [];
  Map<String, dynamic>? _categoriaSeleccionada;
  bool _cargandoCategorias = false;
  bool _mostrandoNuevaCategoria = false;
  bool _enviandoCategoria = false;

  // Servicio dentro de la categoría — cada aliado lo nombra a su manera,
  // no hay catálogo para buscar/elegir: se crea directo.
  Map<String, dynamic>? _servicioSeleccionado;
  bool _enviandoServicio = false;
  final List<File> _fotosPortafolio = [];

  // Servicio para el que `POST /services` ya subió estas fotos (aliado
  // proponiendo un servicio nuevo). Si el aliado sigue con ese mismo
  // servicio, no le volvemos a pedir fotos en "Guardar y continuar" —
  // ya quedaron asociadas a (servicio, aliado) en ese paso.
  int? _fotosYaSubidasParaServicioId;

  bool _isSaving = false;

  // Un motivo por campo + el aviso general del formulario.
  String? _errorCategoria;
  String? _errorServicio;
  String? _errorNuevoServicioNombre;
  String? _errorNuevoServicioDescripcion;
  String? _errorPortafolio;
  String? _avisoGeneral;

  bool get _categoriaEsAprobada =>
      _categoriaSeleccionada != null &&
      _categoriaSeleccionada!['review_status'] == 'approved';

  @override
  void initState() {
    super.initState();
    for (final f in [_focoServicioNombre, _focoServicioDescripcion]) {
      f.addListener(() => setState(() {}));
    }
    detectarDispositivo();
    _fetchCategorias();
    _categoriaSearchController.addListener(_filterCategorias);
  }

  @override
  void dispose() {
    _categoriaSearchController.dispose();
    _nuevaCategoriaController.dispose();
    _nuevoServicioNombreController.dispose();
    _nuevoServicioDescripcionController.dispose();
    _focoServicioNombre.dispose();
    _focoServicioDescripcion.dispose();
    super.dispose();
  }

  Future<void> _fetchCategorias() async {
    setState(() => _cargandoCategorias = true);
    try {
      final categorias = await CategoriaApi.listar();
      setState(() {
        _categorias = categorias;
        _categoriasFiltradas = List.from(_categorias);
      });
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
    } finally {
      if (mounted) setState(() => _cargandoCategorias = false);
    }
  }

  void _filterCategorias() {
    final query = _categoriaSearchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _categoriasFiltradas = List.from(_categorias);
        _mostrandoNuevaCategoria = false;
      } else {
        _categoriasFiltradas = _categorias
            .where((c) => (c['name'] as String).toLowerCase().contains(query))
            .toList();
        _mostrandoNuevaCategoria =
            _categoriasFiltradas.isEmpty && query.isNotEmpty;
      }
    });
  }

  void _elegirCategoria(Map<String, dynamic> categoria) {
    setState(() {
      _categoriaSeleccionada = categoria;
      _errorCategoria = null;
      _revisarAviso();
      _categoriaSearchController.text = categoria['name'];
      _categoriasFiltradas = [];
      // Cambiar de categoría descarta el servicio elegido de la anterior.
      _servicioSeleccionado = null;
    });
  }

  Future<void> _sugerirCategoria() async {
    final nombre = _nuevaCategoriaController.text.trim();
    if (nombre.isEmpty) return;

    setState(() => _enviandoCategoria = true);
    try {
      final data = await CategoriaApi.sugerir(
        nombre: nombre,
        allyEmail: widget.email,
      );
      if (!mounted) return;
      setState(() {
        _categoriaSeleccionada = data;
        _errorCategoria = null;
        _categoriaSearchController.text = data['name'];
        _categoriasFiltradas = [];
        _mostrandoNuevaCategoria = false;
        _nuevaCategoriaController.clear();
      });
      _showSnack(context.tr('category_suggested'));
    } catch (e) {
      _showSnack(_mensajeError(e), isError: true);
    } finally {
      if (mounted) setState(() => _enviandoCategoria = false);
    }
  }

  Future<void> _agregarFotoPortafolio(ImageSource source) async {
    if (_fotosPortafolio.length >= 5) return;
    await tomarFoto(
      etiqueta: 'SERVICIO',
      source: source,
      noRepetirDe: _fotosPortafolio,
      onRepetida: () => _showSnack(context.tr('photo_duplicated'), isError: true),
      onListo: (f) {
        _fotosPortafolio.add(f);
        _errorPortafolio = null;
      },
    );
  }

  void _previsualizarFoto(File foto) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.file(foto, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Crea el servicio en el catálogo. Devuelve true si quedó creado.
  ///
  /// Ya no es el handler de un botón propio: el formulario tiene un solo botón,
  /// el de abajo, y este paso ocurre dentro de él. Tener dos botones hacía
  /// pensar que había que guardar el servicio aparte antes de continuar.
  Future<bool> _crearServicio() async {
    if (_categoriaSeleccionada == null) return false;

    final nombre = _nuevoServicioNombreController.text.trim();
    final descripcion = _nuevoServicioDescripcionController.text.trim();

    final errorNombre = nombre.length < 3 ? context.tr('service_name_too_short') : null;
    // Palabras, no caracteres: "puertas" son 7 caracteres y no describe nada.
    // Mismo criterio que la frase de presentación y la experiencia.
    final errorDescripcion = Validacion.palabras(descripcion) < 5
        ? context.tr('service_description_required')
        : null;
    final errorFotos = _fotosPortafolio.isEmpty ? context.tr('portfolio_required') : null;

    setState(() {
      _errorNuevoServicioNombre = errorNombre;
      _errorNuevoServicioDescripcion = errorDescripcion;
      _errorPortafolio = errorFotos;
    });

    if (errorNombre != null || errorDescripcion != null || errorFotos != null) {
      setState(() => _avisoGeneral = Validacion.textoCamposFaltantes);
      return false;
    }

    setState(() => _enviandoServicio = true);
    try {
      final imagenes = await Future.wait(
        _fotosPortafolio.map((f) async => base64Encode(await f.readAsBytes())),
      );

      final data = await ServicioApi.crear(
        nombre: nombre,
        descripcion: descripcion,
        categoryId: _categoriaSeleccionada!['id'],
        allyEmail: widget.email,
        imagenes: imagenes,
      );

      if (!mounted) return false;
      setState(() {
        _servicioSeleccionado = data;
        _fotosYaSubidasParaServicioId = data['id'] as int?;
        _errorServicio = null;
        _nuevoServicioNombreController.clear();
        _nuevoServicioDescripcionController.clear();
        _fotosPortafolio.clear();
        _errorNuevoServicioNombre = null;
        _errorNuevoServicioDescripcion = null;
        _errorPortafolio = null;
        _avisoGeneral = null;
      });
      return true;
    } catch (e) {
      // También en el aviso del formulario: el snack se va solo y el aliado se
      // queda mirando un botón que "no hizo nada".
      final mensaje = _mensajeError(e);
      if (mounted) setState(() => _avisoGeneral = mensaje);
      _showSnack(mensaje, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _enviandoServicio = false);
    }
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorCategoria == null &&
        _errorServicio == null) {
      _avisoGeneral = null;
    }
  }

  Future<void> _guardarYContinuar() async {
    // Sin categoría no hay dónde crear el servicio: se corta antes de intentarlo.
    if (_categoriaSeleccionada == null) {
      setState(() {
        _errorCategoria = context.tr('select_or_create_service');
        _avisoGeneral = Validacion.textoCamposFaltantes;
      });
      return;
    }

    // El servicio se crea acá, no en un botón aparte. `_crearServicio` marca en
    // rojo lo que falte y devuelve false.
    if (_servicioSeleccionado == null) {
      final creado = await _crearServicio();
      if (!creado || !mounted) return;
    }

    final faltanFotos =
        _fotosYaSubidasParaServicioId != _servicioSeleccionado!['id'] &&
            _fotosPortafolio.isEmpty;

    if (faltanFotos) {
      setState(() {
        _errorPortafolio = context.tr('portfolio_required');
        _avisoGeneral = Validacion.textoCamposFaltantes;
      });
      return;
    }

    setState(() {
      _errorCategoria = null;
      _errorServicio = null;
      _errorPortafolio = null;
      _avisoGeneral = null;
      _isSaving = true;
    });

    try {
      final imagenes = await Future.wait(
        _fotosPortafolio.map((f) async => base64Encode(await f.readAsBytes())),
      );

      // Nombre comercial, frase y experiencia ya no viajan acá: se piden una
      // sola vez en el paso de perfil y el backend los copia desde `allies`.
      await AliadoApi.crearPerfilServicio({
        'email': widget.email,
        'service_id': _servicioSeleccionado!['id'],
        'images': imagenes,
      });

      if (!mounted) return;

      // Registrar sesión del aliado (nuevo dispositivo o recién registrado)
      final sessionService =
          Provider.of<SessionService>(context, listen: false);
      await sessionService.registerSession(widget.email);

      if (!mounted) return;
      // El servicio no queda publicado de inmediato: se le explica acá, que es
      // cuando lo tiene presente, y no en un aviso suelto más adelante.
      await _mostrarEnviadoARevision();

      if (!mounted) return;
      final destino = await AllyRouting.resolveDestination(widget.email);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destino,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } catch (e) {
      // Sea cual sea el error creando el perfil, dejamos que la rutina de
      // ruteo decida el destino real en vez de asumir que quedó aprobado.
      if (!mounted) return;
      final destino = await AllyRouting.resolveDestination(widget.email);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destino,
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

  /// Cierre del formulario: el servicio quedó enviado, no publicado.
  Future<void> _mostrarEnviadoARevision() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brandColor.withOpacity(0.12),
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 36, color: _brandColor),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('service_sent_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('service_sent_body'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: Colors.black.withOpacity(0.6)),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.tr('understood'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mensaje presentable: el del servidor solo cuando el aliado puede
  /// corregirlo (4xx). Un fallo nuestro sale como texto amable y genérico.
  String _mensajeError(Object e) => mensajeParaElAliado(
        e,
        siEsNuestro: context.tr('error_nuestro'),
        siNoHayRed: context.tr('error_sin_red'),
      );

  void _showSnack(String msg, {bool isError = false}) {
    // `floating` acá lo descartaba Flutter con "Floating SnackBar presented off
    // screen" — el formulario scrollea y el snack quedaba fuera de la vista, así
    // que los errores del servidor no se veían y el botón parecía no hacer nada.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _brandColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarSoporte() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('support_soon_title')),
        content: Text(context.tr('support_soon_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('accept')),
          ),
        ],
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
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 40,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu',
                  style: const TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 30,
                    color: _brandColor,
                    height: 0.85,
                  ),
                ),
                Text(
                  'Du',
                  style: const TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 30,
                    color: _brandColor,
                    height: 0.85,
                  ),
                ),
              ],
            ),
          ),
        ),
        leading: widget.esOpcional
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              )
            : null,
        actions: widget.esOpcional
            ? [
                IconButton(
                  icon: const Icon(Icons.support_agent, color: Colors.black87),
                  onPressed: _mostrarSoporte,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Solo el progreso queda fijo bajo la AppBar. Título, subtítulo
            // y el resto del formulario scrollean.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: _buildProgressIndicator(step: 4),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 20),

                    // ─── Categoría ──────────────────────────────────────────
                    Text(
                      context.tr('service_category'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSeleccionado(
                      seleccionado: _categoriaSeleccionada,
                      pendiente: _categoriaSeleccionada != null &&
                          !_categoriaEsAprobada,
                      onQuitar: () => setState(() {
                        _categoriaSeleccionada = null;
                        _categoriaSearchController.clear();
                        _servicioSeleccionado = null;
                        _fotosPortafolio.clear();
                        _fotosYaSubidasParaServicioId = null;
                        _errorPortafolio = null;
                      }),
                    ),
                    if (_categoriaSeleccionada == null) ...[
                      _buildBuscador(
                        controller: _categoriaSearchController,
                        hint: context.tr('search_category_hint'),
                        error: _errorCategoria,
                        onClear: () => setState(() {
                          _errorCategoria = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (_cargandoCategorias)
                        _buildCargando()
                      else if (_categoriasFiltradas.isNotEmpty)
                        _buildLista(
                          items: _categoriasFiltradas,
                          onTap: _elegirCategoria,
                        ),
                      if (_mostrandoNuevaCategoria ||
                          (_categoriasFiltradas.isEmpty &&
                              _categoriaSearchController.text.isNotEmpty))
                        _buildSugerirCategoria(),
                    ],
                    const SizedBox(height: 24),

                    // ─── Servicio dentro de la categoría ───────────────────
                    if (_categoriaSeleccionada != null) ...[
                      Text(
                        context.tr('service_name_label'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSeleccionado(
                        seleccionado: _servicioSeleccionado,
                        pendiente: _servicioSeleccionado != null &&
                            _servicioSeleccionado!['review_status'] !=
                                'approved',
                        onQuitar: () => setState(() {
                          _servicioSeleccionado = null;
                          _fotosPortafolio.clear();
                          _fotosYaSubidasParaServicioId = null;
                          _errorPortafolio = null;
                        }),
                      ),
                      // Cada aliado nombra su servicio a su manera — no hay
                      // catálogo para buscar ni elegir uno existente, se crea
                      // directo dentro de la categoría.
                      if (_servicioSeleccionado == null) _buildCrearServicio(),
                      const SizedBox(height: 24),
                    ],

                    // Aviso informativo
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _brandColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _brandColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        context.tr('service_setup_tip'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.6),
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Pruebas de este servicio ─────────────────────────
                    // Va al final a propósito: es lo último que se pide antes
                    // de guardar. El servicio del catálogo puede ya existir
                    // (propuesto por otro aliado) — cada aliado igual prueba
                    // con sus propias fotos que él hace ese trabajo. Si ya se
                    // enviaron al proponer un servicio nuevo, no se piden de nuevo.
                    if (_servicioSeleccionado != null &&
                        _fotosYaSubidasParaServicioId !=
                            _servicioSeleccionado!['id']) ...[
                      _buildPortafolio(),
                      if (_errorPortafolio != null) ...[
                        const SizedBox(height: 6),
                        Text(_errorPortafolio!,
                            style: TextStyle(
                                fontSize: 12, color: Validacion.colorError)),
                      ],
                      const SizedBox(height: 20),
                    ],
                    if (_servicioSeleccionado != null &&
                        _fotosYaSubidasParaServicioId ==
                            _servicioSeleccionado!['id']) ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: _brandColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr('portfolio_already_sent'),
                              style: TextStyle(fontSize: 12, color: _brandColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                // `esOpcional` es true solo cuando entra por
                                // "Agregar" desde Mis Servicios: ahí ya no es
                                // el primero.
                                context.tr(widget.esOpcional
                                    ? 'create_service'
                                    : 'create_first_service'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip del elemento elegido (categoría o servicio), con badge si está
  /// pendiente de revisión — recién propuesto, todavía no lo aprobó el admin.
  Widget _buildSeleccionado({
    required Map<String, dynamic>? seleccionado,
    required bool pendiente,
    required VoidCallback onQuitar,
  }) {
    if (seleccionado == null) return const SizedBox.shrink();

    final color = pendiente ? Colors.orange.shade800 : _brandColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pendiente ? Icons.hourglass_top : Icons.check_circle,
              color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seleccionado['name'],
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                if (pendiente)
                  Text(
                    context.tr('pending_review_badge'),
                    style: TextStyle(color: color, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onQuitar,
            child: Icon(Icons.close, color: color, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscador({
    required TextEditingController controller,
    required String hint,
    required String? error,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      decoration: Validacion.decorar(
        InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
          prefixIcon: Icon(Icons.search, color: Colors.black.withOpacity(0.4)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.black.withOpacity(0.4)),
                  onPressed: () {
                    controller.clear();
                    onClear();
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
        error: error,
      ),
    );
  }

  Widget _buildCargando() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: _brandColor),
      ),
    );
  }

  Widget _buildLista({
    required List<Map<String, dynamic>> items,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    return Container(
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
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.black.withOpacity(0.07)),
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.work_outline, color: _brandColor, size: 20),
            title: Text(
              item['name'],
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildSugerirCategoria() {
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
                  Expanded(
                    child: Text(
                      context.tr('category_not_found'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nuevaCategoriaController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco(
                  context.tr('new_category_name'),
                  hint: context.tr('new_category_hint'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _enviandoCategoria ? null : _sugerirCategoria,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _brandColor, width: 1.5),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _enviandoCategoria
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _brandColor),
                        )
                      : Text(
                          context.tr('suggest_category'),
                          style: TextStyle(
                              color: _brandColor, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrearServicio() {
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
                  Expanded(
                    child: Text(
                      context.tr('service_not_found'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nuevoServicioNombreController,
                focusNode: _focoServicioNombre,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                onChanged: (_) => setState(() => _errorNuevoServicioNombre = null),
                decoration: Validacion.decorar(
                  _inputDeco(
                    context.tr('new_service_name'),
                    hint: context.tr('new_service_hint'),
                  ),
                  error: _errorNuevoServicioNombre,
                ),
              ),
              _contador(_nuevoServicioNombreController, _focoServicioNombre, 60,
                  minCaracteres: 3),
              const SizedBox(height: 10),
              TextField(
                controller: _nuevoServicioDescripcionController,
                focusNode: _focoServicioDescripcion,
                maxLength: 120,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _errorNuevoServicioDescripcion = null),
                decoration: Validacion.decorar(
                  _inputDeco(
                    context.tr('new_service_description'),
                    hint: context.tr('new_service_description_hint'),
                  ),
                  error: _errorNuevoServicioDescripcion,
                ),
              ),
              _contador(_nuevoServicioDescripcionController,
                  _focoServicioDescripcion, 120,
                  minPalabras: 5),
              const SizedBox(height: 14),
              _buildPortafolio(),
              if (_errorPortafolio != null) ...[
                const SizedBox(height: 6),
                Text(_errorPortafolio!,
                    style: TextStyle(fontSize: 12, color: Validacion.colorError)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortafolio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_back_outlined, color: _brandColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('portfolio_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              '${_fotosPortafolio.length}/5',
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Botones fijos: no se mueven ni desaparecen al agregar fotos.
        Row(
          children: [
            Expanded(
              child: _buildBotonFuente(
                icon: Icons.camera_alt_rounded,
                label: context.tr('camera'),
                onTap: () => _agregarFotoPortafolio(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBotonFuente(
                icon: Icons.photo_library_rounded,
                label: context.tr('gallery'),
                onTap: () => _agregarFotoPortafolio(ImageSource.gallery),
              ),
            ),
          ],
        ),

        if (_fotosPortafolio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < _fotosPortafolio.length; i++)
                GestureDetector(
                  onTap: () => _previsualizarFoto(_fotosPortafolio[i]),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _fotosPortafolio[i],
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _fotosPortafolio.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade900, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('portfolio_disclaimer'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.orange.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotonFuente({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final deshabilitado = _fotosPortafolio.length >= 5;
    return GestureDetector(
      onTap: deshabilitado ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: deshabilitado
              ? Colors.black.withOpacity(0.04)
              : _brandColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: deshabilitado
                ? Colors.black.withOpacity(0.1)
                : _brandColor.withOpacity(0.4),
            width: 1.3,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: deshabilitado ? Colors.black26 : _brandColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: deshabilitado ? Colors.black38 : _brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator({required int step}) {
    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
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
                  if (i < 3) const SizedBox(width: 4),
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
            _stepLabel(context.tr('step_profile'), step >= 3),
            _stepLabel(context.tr('step_service'), step >= 4),
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

  /// Cuánto llevas de lo que el campo exige.
  ///
  /// Mientras no alcanza el mínimo cuenta hacia él ("3/5 palabras"): es lo que
  /// la persona necesita saber para poder enviar. Cumplido el mínimo pasa a
  /// mostrar el espacio que queda ("87/120"). Pasarse del tope no se avisa
  /// porque no puede ocurrir: `maxLength` deja de aceptar teclas.
  ///
  /// Solo se ve mientras se escribe ese campo, y nunca en rojo: el rojo lo pone
  /// el error del campo al enviar.
  Widget _contador(
    TextEditingController controller,
    FocusNode foco,
    int maxLength, {
    int? minPalabras,
    int? minCaracteres,
  }) {
    if (!foco.hasFocus) return const SizedBox.shrink();

    final texto = controller.text;
    final caracteres = texto.characters.length;

    String etiqueta;
    if (minPalabras != null) {
      final palabras = Validacion.palabras(texto);
      etiqueta = palabras < minPalabras
          ? '$palabras/$minPalabras ${context.tr('words_label')}'
          : '$caracteres/$maxLength';
    } else if (minCaracteres != null && caracteres < minCaracteres) {
      etiqueta = '$caracteres/$minCaracteres';
    } else {
      etiqueta = '$caracteres/$maxLength';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          etiqueta,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11.5, color: Colors.black.withOpacity(0.45)),
        ),
      ),
    );
  }
}
