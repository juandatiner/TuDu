import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import '../services/ally_routing.dart';
import '../services/session_service.dart';
import '../widgets/camera_capture_mixin.dart';
import '../widgets/validacion_formulario.dart';

/// Perfil comercial del aliado: foto, cómo se presenta y su experiencia.
///
/// Va entre el KYC y el primer servicio. Estos datos describen al aliado, no al
/// servicio: antes se pedían dentro del formulario de cada servicio y había que
/// reescribirlos por cada uno aunque la respuesta fuera siempre la misma.
class AllyProfileSetupScreen extends StatefulWidget {
  final String email;

  /// Datos ya guardados (cuando vuelve a esta pantalla a completar algo).
  final Map<String, dynamic>? perfil;

  const AllyProfileSetupScreen({super.key, required this.email, this.perfil});

  @override
  State<AllyProfileSetupScreen> createState() => _AllyProfileSetupScreenState();
}

class _AllyProfileSetupScreenState extends State<AllyProfileSetupScreen>
    with CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  late final TextEditingController _nombreComercialController;
  late final TextEditingController _frasePresentacionController;
  late final TextEditingController _resumenController;

  // El contador de caracteres y palabras solo se ve mientras se escribe ese
  // campo: leyendo el formulario no aporta nada.
  final _focoComercial = FocusNode();
  final _focoFrase = FocusNode();
  final _focoResumen = FocusNode();

  File? _foto;
  String? _fotoActualUrl;
  bool _guardando = false;

  String? _errorFoto;
  String? _errorNombreComercial;
  String? _errorFrase;
  String? _errorResumen;
  String? _avisoGeneral;

  @override
  void initState() {
    super.initState();
    detectarDispositivo();
    final p = widget.perfil ?? const {};
    _nombreComercialController = TextEditingController(text: p['nombre_comercial'] ?? '');
    _frasePresentacionController =
        TextEditingController(text: p['frase_presentacion'] ?? '');
    _resumenController = TextEditingController(text: p['resumen'] ?? '');

    for (final c in [
      _nombreComercialController,
      _frasePresentacionController,
      _resumenController,
    ]) {
      c.addListener(() => setState(() {}));
    }
    for (final f in [_focoComercial, _focoFrase, _focoResumen]) {
      f.addListener(() => setState(() {}));
    }
    _fotoActualUrl = p['avatar_image'] as String?;
  }

  @override
  void dispose() {
    _nombreComercialController.dispose();
    _frasePresentacionController.dispose();
    _resumenController.dispose();
    _focoComercial.dispose();
    _focoFrase.dispose();
    _focoResumen.dispose();
    super.dispose();
  }

  /// Solo galería, igual que la foto de perfil en la app de usuarios: es una
  /// foto elegida, no una selfie tomada en el momento. La de la cámara es la
  /// del KYC, que es otra cosa y sí se toma en vivo.
  Future<void> _elegirFoto() async {
    await tomarFoto(
      etiqueta: 'PERFIL',
      source: ImageSource.gallery,
      onListo: (f) {
        _foto = f;
        _errorFoto = null;
        _revisarAviso();
      },
    );
  }

  /// El aviso general solo tiene sentido mientras quede algún campo en rojo.
  void _revisarAviso() {
    if (_errorFoto == null &&
        _errorNombreComercial == null &&
        _errorFrase == null &&
        _errorResumen == null) {
      _avisoGeneral = null;
    }
  }

  Future<void> _guardar() async {
    // Todo se revisa de una pasada: lo que falte queda marcado en rojo.
    final nombre = _nombreComercialController.text.trim();
    final frase = _frasePresentacionController.text.trim();
    final resumen = _resumenController.text.trim();

    final errorFoto =
        (_foto == null && (_fotoActualUrl ?? '').isEmpty) ? context.tr('photo_required') : null;
    // El perfil es público y pasa por revisión: un teléfono o una dirección lo
    // hacen rebotar, así que se corta acá y no después de enviarlo.
    final sinContacto = context.tr('no_contact_error');

    final errorNombre = nombre.isEmpty
        ? Validacion.requerido
        : (nombre.length < 3
            ? context.tr('commercial_name_too_short')
            : (Validacion.tieneDatosDeContacto(nombre) ? sinContacto : null));
    final errorFrase = frase.isEmpty
        ? Validacion.requerido
        : (Validacion.palabras(frase) < 3
            ? context.tr('pitch_too_short')
            : (Validacion.tieneDatosDeContacto(frase) ? sinContacto : null));
    final errorResumen = resumen.isEmpty
        ? Validacion.requerido
        : (Validacion.palabras(resumen) < 15
            ? context.tr('summary_too_short')
            : (Validacion.tieneDatosDeContacto(resumen) ? sinContacto : null));

    final hayErrores = errorFoto != null ||
        errorNombre != null ||
        errorFrase != null ||
        errorResumen != null;

    setState(() {
      _errorFoto = errorFoto;
      _errorNombreComercial = errorNombre;
      _errorFrase = errorFrase;
      _errorResumen = errorResumen;
      _avisoGeneral = hayErrores ? Validacion.textoCamposFaltantes : null;
    });

    if (hayErrores) return;

    setState(() => _guardando = true);

    try {
      await AliadoApi.guardarPerfil(
        email: widget.email,
        nombreComercial: nombre,
        frasePresentacion: frase,
        resumen: resumen,
      );

      // La foto no se guarda directo: la revisa el admin, igual que la de un
      // cliente. Hasta que la apruebe, el perfil la muestra como "en revisión".
      if (_foto != null) {
        await SolicitudFotoAliadoService.crear(
          widget.email,
          base64Encode(await _foto!.readAsBytes()),
        );
      }

      if (!mounted) return;
      // La sesión se registra acá y no en el paso del servicio: a partir de
      // este punto el aliado ya tiene identidad propia en la app.
      await Provider.of<SessionService>(context, listen: false)
          .registerSession(widget.email);

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
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _avisoGeneral = _mensajeError(e);
        // El nombre comercial no se repite entre aliados: si el backend lo
        // rechaza por eso, se marca el campo concreto y no solo el aviso de
        // arriba, que obliga a adivinar cuál de los tres corregir.
        if (e is ApiException && e.code == 'NOMBRE_COMERCIAL_EN_USO') {
          _errorNombreComercial = e.message;
        }
      });
    }
  }

  /// Mensaje presentable: el del servidor solo cuando el aliado puede
  /// corregirlo (4xx). Un fallo nuestro sale como texto amable y genérico.
  String _mensajeError(Object e) => mensajeParaElAliado(
        e,
        siEsNuestro: context.tr('error_nuestro'),
        siNoHayRed: context.tr('error_sin_red'),
      );

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
        centerTitle: true,
        title: const Text(
          'TuDu',
          style: TextStyle(fontFamily: 'TitanOne', fontSize: 26, color: _brandColor),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('ally_profile_title'),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('ally_profile_intro'),
                style: TextStyle(
                    fontSize: 14, color: Colors.black.withOpacity(0.55), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildFoto(),
              const SizedBox(height: 8),
              Text(
                context.tr('photo_needs_review'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.black.withOpacity(0.45)),
              ),
              if (_errorFoto != null) ...[
                const SizedBox(height: 8),
                Text(_errorFoto!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Validacion.colorError)),
              ],
              const SizedBox(height: 20),

              // La regla del perfil público se dice antes de escribirlo, no
              // solo cuando el guardado la rechaza.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFB26A00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('no_contact_note'),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B4A00),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Nombre comercial ─────────────────────────────────────
              _etiqueta(context.tr('your_business_name')),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreComercialController,
                focusNode: _focoComercial,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {
                  _errorNombreComercial = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(context.tr('commercial_name'),
                      hint: context.tr('commercial_name_hint')),
                  error: _errorNombreComercial,
                ),
              ),
              _contador(_nombreComercialController, _focoComercial, 50,
                  minCaracteres: 3),
              const SizedBox(height: 12),

              // ─── Frase de presentación ────────────────────────────────
              _etiqueta(context.tr('pitch_title')),
              const SizedBox(height: 6),
              _ayuda(context.tr('pitch_help')),
              const SizedBox(height: 8),
              TextField(
                controller: _frasePresentacionController,
                focusNode: _focoFrase,
                maxLength: 80,
                onChanged: (_) => setState(() {
                  _errorFrase = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(context.tr('pitch_label'), hint: context.tr('pitch_hint')),
                  error: _errorFrase,
                ),
              ),
              _contador(_frasePresentacionController, _focoFrase, 80,
                  minPalabras: 3),
              const SizedBox(height: 12),

              // ─── Resumen / experiencia ────────────────────────────────
              _etiqueta(context.tr('summary_title')),
              const SizedBox(height: 6),
              _ayuda(context.tr('summary_help')),
              const SizedBox(height: 8),
              TextField(
                controller: _resumenController,
                focusNode: _focoResumen,
                maxLength: 400,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {
                  _errorResumen = null;
                  _revisarAviso();
                }),
                decoration: Validacion.decorar(
                  _inputDeco(context.tr('summary_label'), hint: context.tr('summary_hint')),
                  error: _errorResumen,
                ),
              ),
              _contador(_resumenController, _focoResumen, 400,
                  minPalabras: 15),

              if (_avisoGeneral != null) ...[
                const SizedBox(height: 16),
                Validacion.aviso(_avisoGeneral!),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.tr('continue_to_service'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) => Text(
        texto,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
      );

  Widget _ayuda(String texto) => Text(
        texto,
        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45), height: 1.4),
      );

  Widget _buildFoto() {
    final borde = _errorFoto != null ? Validacion.colorError : _brandColor;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _elegirFoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: borde, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _foto != null
                  ? Image.file(_foto!, fit: BoxFit.cover)
                  : ((_fotoActualUrl ?? '').isNotEmpty
                      ? Image.network(_fotoActualUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderFoto())
                      : _placeholderFoto()),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _elegirFoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              _foto != null || (_fotoActualUrl ?? '').isNotEmpty
                  ? context.tr('change_photo')
                  : context.tr('add_profile_photo'),
            ),
            style: TextButton.styleFrom(foregroundColor: _brandColor),
          ),
        ],
      ),
    );
  }

  Widget _placeholderFoto() => Icon(
        Icons.person_outline,
        size: 54,
        color: Colors.black.withOpacity(0.25),
      );

  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      // El contador de `maxLength` se apaga: abajo va el nuestro, que cuenta lo
      // que el campo exige. Con los dos encendidos salían dos contadores.
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandColor, width: 1.6),
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
