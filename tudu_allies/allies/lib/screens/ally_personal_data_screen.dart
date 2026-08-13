import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import '../widgets/camera_capture_mixin.dart';
import '../widgets/validacion_formulario.dart';
import 'home_screen.dart' show kAzulAliado;

/// "Mis datos" del aliado: los mismos gestos que la pantalla equivalente de la
/// app de usuarios — foto arriba, campos agrupados en tarjetas, guardado
/// explícito — pero con lo que un aliado tiene: nombre, cómo se presenta al
/// cliente y su experiencia.
///
/// La foto no se cambia en el acto: crea una solicitud que revisa el admin,
/// igual que la de un cliente.
class AllyPersonalDataScreen extends StatefulWidget {
  final String email;

  const AllyPersonalDataScreen({super.key, required this.email});

  @override
  State<AllyPersonalDataScreen> createState() => _AllyPersonalDataScreenState();
}

class _AllyPersonalDataScreenState extends State<AllyPersonalDataScreen>
    with CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  /// Tope de peso de la foto, como en la app de usuarios: una imagen de 20 MB
  /// en base64 infla el cuerpo del request sin ninguna ganancia visible.
  static const int _maxMb = 5;

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _nombreComercialController = TextEditingController();
  final _fraseController = TextEditingController();
  final _resumenController = TextEditingController();

  Map<String, dynamic> _ally = const {};
  Map<String, dynamic>? _fotoPendiente;

  bool _cargando = true;
  bool _guardando = false;

  String? _errorNombre;
  String? _errorApellido;
  String? _errorNombreComercial;
  String? _errorFrase;
  String? _errorResumen;
  String? _avisoGeneral;

  @override
  void initState() {
    super.initState();
    detectarDispositivo();
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _nombreComercialController.dispose();
    _fraseController.dispose();
    _resumenController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final estado = await AliadoApi.estado(widget.email);
      final pendiente = await SolicitudFotoAliadoService.pendiente(widget.email);
      if (!mounted) return;

      final ally = estado['ally'] is Map
          ? Map<String, dynamic>.from(estado['ally'])
          : <String, dynamic>{};

      setState(() {
        _ally = ally;
        _fotoPendiente = pendiente;
        _nombreController.text = ally['nombre'] ?? '';
        _apellidoController.text = ally['apellido'] ?? '';
        _nombreComercialController.text = ally['nombre_comercial'] ?? '';
        _fraseController.text = ally['frase_presentacion'] ?? '';
        _resumenController.text = ally['resumen'] ?? '';
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _avisoGeneral = _mensajeError(e);
      });
    }
  }

  String _mensajeError(Object e) => mensajeParaElAliado(
        e,
        siEsNuestro: context.tr('error_nuestro'),
        siNoHayRed: context.tr('error_sin_red'),
      );

  Future<void> _cambiarFoto() async {
    await tomarFoto(
      etiqueta: 'PERFIL',
      source: ImageSource.gallery,
      onListo: (archivo) => _enviarFoto(archivo),
    );
  }

  Future<void> _enviarFoto(File archivo) async {
    final mb = await archivo.length() / (1024 * 1024);
    if (mb > _maxMb) {
      _avisar(context.tr('photo_too_heavy'), esError: true);
      return;
    }

    try {
      await SolicitudFotoAliadoService.crear(
        widget.email,
        base64Encode(await archivo.readAsBytes()),
      );
      if (!mounted) return;
      _avisar(context.tr('photo_under_review'));
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      _avisar(_mensajeError(e), esError: true);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final comercial = _nombreComercialController.text.trim();
    final frase = _fraseController.text.trim();
    final resumen = _resumenController.text.trim();

    final errorNombre = nombre.isEmpty ? Validacion.requerido : null;
    final errorApellido = apellido.isEmpty ? Validacion.requerido : null;
    final errorComercial = comercial.length < 3
        ? context.tr('commercial_name_too_short')
        : null;
    final errorFrase =
        Validacion.palabras(frase) < 3 ? context.tr('pitch_too_short') : null;
    final errorResumen =
        Validacion.palabras(resumen) < 15 ? context.tr('summary_too_short') : null;

    final hayErrores = errorNombre != null ||
        errorApellido != null ||
        errorComercial != null ||
        errorFrase != null ||
        errorResumen != null;

    setState(() {
      _errorNombre = errorNombre;
      _errorApellido = errorApellido;
      _errorNombreComercial = errorComercial;
      _errorFrase = errorFrase;
      _errorResumen = errorResumen;
      _avisoGeneral = hayErrores ? Validacion.textoCamposFaltantes : null;
    });

    if (hayErrores) return;

    setState(() => _guardando = true);

    try {
      // Dos endpoints porque son dos cosas distintas: los datos personales
      // viven en el registro del aliado y el perfil comercial es lo que ve el
      // usuario. `register-ally` hace upsert, así que sirve para actualizar.
      await AliadoApi.registrar(
        email: widget.email,
        nombre: nombre,
        apellido: apellido,
        fechaNacimiento: _ally['fecha_nacimiento'] as String?,
      );

      await AliadoApi.guardarPerfil(
        email: widget.email,
        nombreComercial: comercial,
        frasePresentacion: frase,
        resumen: resumen,
      );

      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(context.tr('data_saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _avisoGeneral = _mensajeError(e);
        if (e is ApiException && e.code == 'NOMBRE_COMERCIAL_EN_USO') {
          _errorNombreComercial = e.message;
        }
      });
    }
  }

  void _avisar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: esError ? Colors.red : _brandColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(context.tr('my_data'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Container(
        color: _bgColor,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: _brandColor))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _buildFoto(),
                  const SizedBox(height: 28),
                  _tarjeta(
                    titulo: context.tr('personal_data'),
                    hijos: [
                      _campo(
                        controller: _nombreController,
                        etiqueta: context.tr('first_name'),
                        error: _errorNombre,
                        onChanged: () => setState(() => _errorNombre = null),
                      ),
                      const SizedBox(height: 14),
                      _campo(
                        controller: _apellidoController,
                        etiqueta: context.tr('last_name'),
                        error: _errorApellido,
                        onChanged: () => setState(() => _errorApellido = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _tarjeta(
                    titulo: context.tr('ally_profile_title'),
                    ayuda: context.tr('ally_profile_intro'),
                    hijos: [
                      _campo(
                        controller: _nombreComercialController,
                        etiqueta: context.tr('commercial_name'),
                        error: _errorNombreComercial,
                        maxLength: 50,
                        onChanged: () =>
                            setState(() => _errorNombreComercial = null),
                      ),
                      const SizedBox(height: 14),
                      _campo(
                        controller: _fraseController,
                        etiqueta: context.tr('pitch_label'),
                        error: _errorFrase,
                        maxLength: 80,
                        onChanged: () => setState(() => _errorFrase = null),
                      ),
                      const SizedBox(height: 14),
                      _campo(
                        controller: _resumenController,
                        etiqueta: context.tr('summary_label'),
                        error: _errorResumen,
                        maxLength: 400,
                        lineas: 5,
                        onChanged: () => setState(() => _errorResumen = null),
                      ),
                    ],
                  ),
                  if (_avisoGeneral != null) ...[
                    const SizedBox(height: 16),
                    Validacion.aviso(_avisoGeneral!),
                  ],
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(context.tr('save_changes'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
      ),
    );
  }

  /// Igual que en la pantalla de datos de la app de usuarios: círculo con
  /// borde blanco y sombra, con la cámara abajo a la derecha. Sin etiquetas de
  /// estado — el resultado de la revisión llega por su propio aviso.
  Widget _buildFoto() {
    final url = (_ally['avatar_image'] as String?) ?? '';

    return Center(
      child: GestureDetector(
        onTap: _cambiarFoto,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: url.isEmpty ? kAzulAliado.withOpacity(0.15) : Colors.transparent,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    spreadRadius: 3,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: url.isEmpty
                  ? Icon(Icons.person, size: 52, color: kAzulAliado.withOpacity(0.7))
                  : Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person,
                          size: 52, color: kAzulAliado.withOpacity(0.7))),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: kAzulAliado,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({
    required String titulo,
    String? ayuda,
    required List<Widget> hijos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (ayuda != null) ...[
            const SizedBox(height: 4),
            Text(ayuda,
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.45), height: 1.4)),
          ],
          const SizedBox(height: 16),
          ...hijos,
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required VoidCallback onChanged,
    String? error,
    int? maxLength,
    int lineas = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: lineas,
      textCapitalization: lineas > 1
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      onChanged: (_) => onChanged(),
      decoration: Validacion.decorar(
        InputDecoration(
          labelText: etiqueta,
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandColor, width: 1.6),
          ),
        ),
        error: error,
      ),
    );
  }
}
