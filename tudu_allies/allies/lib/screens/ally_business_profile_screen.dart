import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import '../widgets/campo_caja.dart';
import '../widgets/validacion_formulario.dart';

/// "Mi perfil de aliado": lo que el usuario lee antes de contratar — nombre
/// comercial, frase corta y resumen profesional.
///
/// Vive aparte de "Mis datos" porque son dos cosas con reglas distintas: los
/// datos personales los fija la cédula y el contacto se guarda directo, mientras
/// que esto es público y cada cambio pasa por revisión del admin. Mezclarlos en
/// una pantalla obligaba a explicar dos veces qué se puede tocar y qué no.
class AllyBusinessProfileScreen extends StatefulWidget {
  final String email;

  const AllyBusinessProfileScreen({super.key, required this.email});

  @override
  State<AllyBusinessProfileScreen> createState() =>
      _AllyBusinessProfileScreenState();
}

class _AllyBusinessProfileScreenState extends State<AllyBusinessProfileScreen> {
  final _nombreComercialController = TextEditingController();
  final _fraseController = TextEditingController();
  final _resumenController = TextEditingController();

  // El contador de caracteres y palabras solo aparece en el campo que se está
  // escribiendo: leyendo el perfil no aporta nada y ensucia la pantalla.
  final _focoComercial = FocusNode();
  final _focoFrase = FocusNode();
  final _focoResumen = FocusNode();

  Map<String, dynamic>? _solicitud;
  bool get _enRevision => _solicitud?['status'] == 'pending';

  bool _cargando = true;
  bool _guardando = false;

  String? _errorNombreComercial;
  String? _errorFrase;
  String? _errorResumen;
  String? _avisoGeneral;

  String _origNombreComercial = '';
  String _origFrase = '';
  String _origResumen = '';

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nombreComercialController,
      _fraseController,
      _resumenController,
    ]) {
      c.addListener(() => setState(() {}));
    }
    for (final f in [_focoComercial, _focoFrase, _focoResumen]) {
      f.addListener(() => setState(() {}));
    }
    _cargar();
  }

  @override
  void dispose() {
    _nombreComercialController.dispose();
    _fraseController.dispose();
    _resumenController.dispose();
    _focoComercial.dispose();
    _focoFrase.dispose();
    _focoResumen.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final estado = await AliadoApi.estado(widget.email);

      // El estado del cambio es información extra: si falla, la pantalla tiene
      // que abrirse igual con el perfil publicado.
      Map<String, dynamic>? solicitud;
      try {
        solicitud = await SolicitudPerfilAliadoService.estado(widget.email);
      } catch (e) {
        debugPrint('No se pudo leer el estado del cambio de perfil: $e');
      }

      if (!mounted) return;

      final ally = estado['ally'] is Map
          ? Map<String, dynamic>.from(estado['ally'])
          : <String, dynamic>{};

      setState(() {
        _solicitud = solicitud;

        // Con un cambio en revisión se muestra lo que el aliado propuso, no lo
        // publicado: si no, parecería que su edición se perdió.
        final enRevision = solicitud != null && solicitud['status'] == 'pending';
        final fuente = enRevision ? solicitud : ally;

        _nombreComercialController.text = fuente['nombre_comercial'] ?? '';
        _fraseController.text = fuente['frase_presentacion'] ?? '';
        _resumenController.text = fuente['resumen'] ?? '';

        _origNombreComercial = _nombreComercialController.text;
        _origFrase = _fraseController.text;
        _origResumen = _resumenController.text;

        _cargando = false;
      });

      // El resultado ya se está mostrando en pantalla: no hace falta volver a
      // anunciarlo la próxima vez que entre.
      final id = solicitud?['id'];
      if (solicitud != null && solicitud['status'] != 'pending' && id != null) {
        SolicitudPerfilAliadoService.marcarNotificada(id as int)
            .catchError((_) {});
      }
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

  bool _hayCambios() =>
      _nombreComercialController.text.trim() != _origNombreComercial.trim() ||
      _fraseController.text.trim() != _origFrase.trim() ||
      _resumenController.text.trim() != _origResumen.trim();

  Future<void> _guardar() async {
    final comercial = _nombreComercialController.text.trim();
    final frase = _fraseController.text.trim();
    final resumen = _resumenController.text.trim();

    final sinContacto = context.tr('no_contact_error');

    final errorComercial = comercial.length < 3
        ? context.tr('commercial_name_too_short')
        : Validacion.tieneDatosDeContacto(comercial)
            ? sinContacto
            : null;
    final errorFrase = Validacion.palabras(frase) < 3
        ? context.tr('pitch_too_short')
        : Validacion.tieneDatosDeContacto(frase)
            ? sinContacto
            : null;
    final errorResumen = Validacion.palabras(resumen) < 15
        ? context.tr('summary_too_short')
        : Validacion.tieneDatosDeContacto(resumen)
            ? sinContacto
            : null;

    final hayErrores =
        errorComercial != null || errorFrase != null || errorResumen != null;

    setState(() {
      _errorNombreComercial = errorComercial;
      _errorFrase = errorFrase;
      _errorResumen = errorResumen;
      _avisoGeneral = hayErrores ? Validacion.textoCamposFaltantes : null;
    });

    if (hayErrores) return;

    setState(() => _guardando = true);

    try {
      final resultado = await AliadoApi.guardarPerfil(
        email: widget.email,
        nombreComercial: comercial,
        frasePresentacion: frase,
        resumen: resumen,
      );

      if (!mounted) return;
      setState(() => _guardando = false);

      // Un aliado con perfil publicado no cambia su texto en el acto: queda a
      // la espera del admin y se queda en la pantalla viendo ese estado.
      if (resultado == 'pending_review') {
        _avisar(context.tr('profile_change_sent'));
        await _cargar();
        return;
      }

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
      backgroundColor: esError ? Colors.red : CampoColores.marca,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hayCambios = _hayCambios();

    return Scaffold(
      backgroundColor: CampoColores.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CampoColores.marca),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('business_profile'),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: CampoColores.marca))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    TituloBloque(context.tr('ally_profile_title'),
                        ayuda: context.tr('ally_profile_intro')),
                    if (_solicitud != null) ...[
                      _estadoSolicitud(),
                      const SizedBox(height: 14),
                    ],
                    _campo(
                      controller: _nombreComercialController,
                      foco: _focoComercial,
                      etiqueta: context.tr('commercial_name'),
                      icono: Icons.storefront_outlined,
                      error: _errorNombreComercial,
                      maxLength: 50,
                      minCaracteres: 3,
                      onChanged: () =>
                          setState(() => _errorNombreComercial = null),
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      controller: _fraseController,
                      foco: _focoFrase,
                      etiqueta: context.tr('pitch_label'),
                      icono: Icons.format_quote_outlined,
                      error: _errorFrase,
                      maxLength: 80,
                      minPalabras: 3,
                      onChanged: () => setState(() => _errorFrase = null),
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      controller: _resumenController,
                      foco: _focoResumen,
                      etiqueta: context.tr('summary_label'),
                      icono: Icons.notes_outlined,
                      error: _errorResumen,
                      maxLength: 400,
                      minPalabras: 15,
                      lineas: 5,
                      onChanged: () => setState(() => _errorResumen = null),
                    ),
                    const SizedBox(height: 16),
                    _avisoContacto(),
                    const SizedBox(height: 32),
                    Validacion.aviso(_avisoGeneral),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _guardando || !hayCambios || _enRevision
                            ? null
                            : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CampoColores.marca,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _guardando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                context.tr('save_changes'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (!hayCambios && !_enRevision)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          context.tr('no_changes'),
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// En qué va el último cambio de perfil: en revisión, aprobado o rechazado
  /// con su motivo. El aliado no tiene otro sitio donde enterarse.
  Widget _estadoSolicitud() {
    final estado = _solicitud!['status'];
    final motivo = _solicitud!['rejection_reason'] as String?;

    late final Color fondo;
    late final Color borde;
    late final Color texto;
    late final IconData icono;
    late final String titulo;
    String? cuerpo;

    if (estado == 'pending') {
      fondo = const Color(0xFFE8F1FC);
      borde = const Color(0xFF2C7BE5);
      texto = const Color(0xFF17457F);
      icono = Icons.hourglass_top;
      titulo = context.tr('profile_change_pending_title');
      cuerpo = context.tr('profile_change_pending_body');
    } else if (estado == 'approved') {
      fondo = const Color(0xFFEDF7E4);
      borde = CampoColores.marca;
      texto = const Color(0xFF3F6A17);
      icono = Icons.check_circle_outline;
      titulo = context.tr('profile_change_approved');
    } else {
      fondo = const Color(0xFFFDECEA);
      borde = Validacion.colorError;
      texto = const Color(0xFF8C2018);
      icono = Icons.error_outline;
      titulo = context.tr('profile_change_rejected');
      cuerpo = motivo;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: borde),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: texto)),
                if (cuerpo != null && cuerpo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(cuerpo,
                      style:
                          TextStyle(fontSize: 12, color: texto, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Regla del perfil público, visible antes de escribirlo y no solo al fallar
  /// el guardado: nada de teléfonos, direcciones ni enlaces.
  Widget _avisoContacto() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB26A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('no_contact_note'),
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B4A00), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required FocusNode foco,
    required String etiqueta,
    required IconData icono,
    required VoidCallback onChanged,
    String? error,
    int? maxLength,
    int? minPalabras,
    int? minCaracteres,
    int lineas = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoCaja(
          icono: icono,
          etiqueta: etiqueta,
          hayError: error != null,
          iconoArriba: lineas > 1,
          // Con un cambio en revisión el texto no se toca: sería una segunda
          // propuesta sobre una que el admin todavía no respondió.
          bloqueado: _enRevision,
          hijo: TextField(
            controller: controller,
            focusNode: foco,
            enabled: !_enRevision,
            maxLength: maxLength,
            maxLines: lineas,
            style: TextStyle(
                fontSize: 16,
                color: _enRevision
                    ? CampoColores.textoSecundario
                    : Colors.black),
            textCapitalization: lineas > 1
                ? TextCapitalization.sentences
                : TextCapitalization.words,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        // Solo mientras se escribe ese campo: es una ayuda para redactar, no un
        // dato del perfil.
        if (maxLength != null && foco.hasFocus)
          _contador(controller, maxLength,
              minPalabras: minPalabras, minCaracteres: minCaracteres),
        Validacion.mensajeCampo(error),
      ],
    );
  }

  /// Cuánto llevas de lo que el campo exige.
  ///
  /// Mientras no alcanza el mínimo cuenta hacia él ("3/15 palabras"); cumplido,
  /// pasa a mostrar el espacio que queda ("87/400"). Pasarse del tope no se
  /// avisa porque no puede ocurrir: `maxLength` deja de aceptar teclas.
  Widget _contador(
    TextEditingController controller,
    int maxLength, {
    int? minPalabras,
    int? minCaracteres,
  }) {
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
          style: const TextStyle(
              fontSize: 11.5, color: CampoColores.textoSecundario),
        ),
      ),
    );
  }
}
