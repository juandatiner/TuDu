import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import '../widgets/camera_capture_mixin.dart';
import 'phone_otp_dialog.dart';
import '../widgets/campo_caja.dart';
import '../widgets/campo_telefono.dart';
import '../widgets/validacion_formulario.dart';

/// "Mis datos" del aliado: quién es y cómo contactarlo.
///
/// Se divide en dos bloques con reglas distintas y por eso se dicen aparte:
///  - **Identidad** (nombres, apellidos, correo, fecha de nacimiento): la fijó
///    la verificación de la cédula, se muestra en gris y no se toca.
///  - **Contacto** (teléfono y género): lo pone el aliado y se guarda directo,
///    porque no lo ve ningún usuario.
///
/// El perfil comercial —lo que sí es público— vive en su propia pantalla
/// (`AllyBusinessProfileScreen`): allá cada cambio pasa por revisión del admin.
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
  /// Tope de peso de la foto, como en la app de usuarios: una imagen de 20 MB
  /// en base64 infla el cuerpo del request sin ninguna ganancia visible.
  static const int _maxMb = 5;

  final _telefonoController = TextEditingController();

  Map<String, dynamic> _ally = const {};
  Map<String, dynamic>? _fotoPendiente;

  bool _cargando = true;
  bool _guardando = false;

  String? _avisoGeneral;
  String? _errorTelefono;

  // Teléfono partido como en la app de usuarios: el número completo se manda al
  // servidor, y el prefijo se guarda aparte para volver a pintar la bandera.
  String _telefonoCompleto = '';
  String _codigoPais = '';
  String _nombrePais = '';
  String _numero = '';
  String _paisInicial = 'CO';
  Key _telefonoKey = UniqueKey();

  String? _genero;

  String _origTelefono = '';
  String? _origGenero;

  @override
  void initState() {
    super.initState();
    detectarDispositivo();
    _telefonoController.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _opcionesGenero() => [
        {'value': 'mujer', 'label': context.tr('woman')},
        {'value': 'hombre', 'label': context.tr('man')},
        {'value': 'no_binario', 'label': context.tr('non_binary')},
        {'value': 'ninguna', 'label': context.tr('none_of_above')},
      ];

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

        _telefonoCompleto = ally['phone'] ?? '';
        _codigoPais = ally['country_code'] ?? '';
        _nombrePais = ally['country_name'] ?? '';
        _numero = ally['phone_number'] ?? '';
        _telefonoController.text = _numero;
        _genero = ally['genero'];

        _origTelefono = _telefonoCompleto;
        _origGenero = _genero;

        _cargando = false;
      });

      // El selector necesita el código ISO del país (CO, MX...), no el prefijo
      // de marcación: se traduce con el catálogo de países del backend.
      if (_codigoPais.isNotEmpty) {
        final iso = await AliadoApi.isoDePrefijo(_codigoPais);
        if (!mounted) return;
        setState(() {
          _paisInicial = iso;
          _telefonoKey = UniqueKey();
        });
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

  Future<void> _cambiarFoto() async {
    // Con una solicitud en curso no se manda otra: la decide el admin, igual
    // que en la app de usuarios.
    if (_fotoPendiente != null) {
      _avisar(context.tr('photo_under_review'));
      return;
    }

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

  /// Sin cambios no hay nada que guardar, así que el botón queda apagado y se
  /// explica por qué. Solo cuenta lo editable: identidad no entra.
  bool _hayCambios() =>
      _telefonoCompleto != _origTelefono || _genero != _origGenero;

  Future<void> _guardar() async {
    final numero = _telefonoController.text.trim();

    final errorTelefono =
        numero.isNotEmpty && numero.length < 6 ? context.tr('phone_too_short') : null;

    setState(() {
      _errorTelefono = errorTelefono;
      _avisoGeneral = errorTelefono != null ? Validacion.textoCamposFaltantes : null;
    });

    if (errorTelefono != null) return;

    // El teléfono se verifica igual que el correo: si cambió, hay que demostrar
    // que se controla el número antes de guardarlo. La verificación graba el
    // teléfono por su cuenta, así que el guardado normal ya no lo toca.
    final telefonoCambio =
        _telefonoCompleto.isNotEmpty && _telefonoCompleto != _origTelefono;

    if (telefonoCambio) {
      final verificado = await mostrarVerificacionTelefono(
        context,
        email: widget.email,
        countryCode: _codigoPais,
        phoneNumber: numero,
        countryName: _nombrePais,
      );

      // Canceló o falló: no se guarda nada, ni siquiera el género. Guardar a
      // medias dejaría el formulario diciendo una cosa y la base otra.
      if (verificado != true) return;
      if (!mounted) return;

      _origTelefono = _telefonoCompleto;
    }

    setState(() => _guardando = true);

    try {
      await AliadoApi.guardarContacto(
        email: widget.email,
        phone: _telefonoCompleto.isEmpty ? null : _telefonoCompleto,
        countryCode: _codigoPais.isEmpty ? null : _codigoPais,
        countryName: _nombrePais.isEmpty ? null : _nombrePais,
        phoneNumber: numero.isEmpty ? null : numero,
        genero: _genero,
      );

      if (!mounted) return;
      setState(() {
        _guardando = false;
        _origTelefono = _telefonoCompleto;
        _origGenero = _genero;
      });
      _avisar(context.tr('data_saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _avisoGeneral = _mensajeError(e);
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
          context.tr('my_data'),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    _buildFoto(),
                    const SizedBox(height: 24),

                    // ─── Identidad (la fija la cédula) ──────────────────────
                    CampoBloqueado(
                      icono: Icons.person_outline,
                      etiqueta: context.tr('first_name'),
                      valor: _ally['nombre'] ?? '',
                    ),
                    const SizedBox(height: 16),
                    CampoBloqueado(
                      icono: Icons.person_outline,
                      etiqueta: context.tr('last_name'),
                      valor: _ally['apellido'] ?? '',
                    ),
                    const SizedBox(height: 16),
                    CampoBloqueado(
                      icono: Icons.email_outlined,
                      etiqueta: context.tr('email'),
                      valor: widget.email,
                    ),
                    const SizedBox(height: 16),
                    CampoBloqueado(
                      icono: Icons.cake_outlined,
                      etiqueta: context.tr('birth_date'),
                      valor: _fechaNacimiento(),
                    ),
                    const SizedBox(height: 8),
                    NotaBloque(context.tr('verified_data_note')),
                    const SizedBox(height: 26),

                    // ─── Contacto (lo pone el aliado) ───────────────────────
                    TituloBloque(context.tr('contact_data'),
                        ayuda: context.tr('contact_data_note')),
                    _campoTelefono(),
                    Validacion.mensajeCampo(_errorTelefono),
                    const SizedBox(height: 16),
                    _campoGenero(),
                    const SizedBox(height: 32),

                    Validacion.aviso(_avisoGeneral),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _guardando || !hayCambios ? null : _guardar,
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
                    if (!hayCambios)
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

  /// Fecha de nacimiento tal como la muestra la app de usuarios: dd/mm/aaaa.
  String _fechaNacimiento() {
    final crudo = (_ally['fecha_nacimiento'] as String?) ?? '';
    if (crudo.isEmpty) return '';

    final fecha = DateTime.tryParse(crudo);
    if (fecha == null) return crudo;

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Widget _campoTelefono() {
    return CampoTelefono(
      key: _telefonoKey,
      controller: _telefonoController,
      isoInicial: _paisInicial,
      error: _errorTelefono,
      onChanged: (pais, numero, completo) {
        setState(() {
          _codigoPais = '+${pais.dialCode}';
          _nombrePais = pais.name;
          _numero = numero;
          _telefonoCompleto = completo;
          _errorTelefono = null;
        });
      },
    );
  }

  Widget _campoGenero() {
    final opciones = _opcionesGenero();
    final elegido = _genero == null
        ? null
        : opciones.firstWhere((o) => o['value'] == _genero,
            orElse: () => {'label': ''})['label'];

    return CampoCaja(
      icono: Icons.wc_outlined,
      etiqueta: context.tr('gender'),
      onTap: _elegirGenero,
      trailing: const Icon(Icons.keyboard_arrow_down, color: CampoColores.marca),
      hijo: Text(
        (elegido == null || elegido.isEmpty) ? context.tr('select') : elegido,
        style: TextStyle(
          fontSize: 16,
          color: (elegido == null || elegido.isEmpty)
              ? CampoColores.textoSecundario
              : Colors.black,
        ),
      ),
    );
  }

  void _elegirGenero() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              child: Text(
                context.tr('select_your_gender'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ..._opcionesGenero().map((opcion) {
              final elegido = _genero == opcion['value'];
              return InkWell(
                onTap: () {
                  setState(() => _genero = opcion['value']);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        elegido
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: elegido
                            ? CampoColores.marca
                            : CampoColores.textoSecundario,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        opcion['label']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              elegido ? FontWeight.w600 : FontWeight.normal,
                          color: elegido ? CampoColores.marca : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Misma geometría que el avatar de "Mis Datos" en la app de usuarios:
  /// círculo de 100 con borde blanco de 4 y sombra, y la cámara de 32 abajo a
  /// la derecha — la foto se toca desde ese botón, no desde el círculo.
  Widget _buildFoto() {
    final url = (_ally['avatar_image'] as String?) ?? '';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: url.isEmpty ? CampoColores.marca : Colors.transparent,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: CampoColores.sombra,
                spreadRadius: 3,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isEmpty
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: CampoColores.marca,
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
        ),
        GestureDetector(
          onTap: _cambiarFoto,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CampoColores.marca,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: CampoColores.sombra,
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
