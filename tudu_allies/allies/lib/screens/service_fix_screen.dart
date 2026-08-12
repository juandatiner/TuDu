import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/ally_api.dart';
import '../widgets/camera_capture_mixin.dart';

/// Corregir un servicio que el admin rechazó y volver a mandarlo a revisión.
///
/// Antes un rechazo era el final del camino: el aliado leía el motivo y no
/// tenía forma de arreglarlo salvo crear otro servicio desde cero. Acá llega
/// con lo que escribió ya cargado, ve el motivo del admin y **cuáles campos**
/// marcó (`rejected_fields`), resaltados para no tener que adivinar.
class ServiceFixScreen extends StatefulWidget {
  /// La fila de `services` tal como la devuelve `/ally-service-profiles`.
  final Map<String, dynamic> servicio;
  final String email;

  const ServiceFixScreen({super.key, required this.servicio, required this.email});

  @override
  State<ServiceFixScreen> createState() => _ServiceFixScreenState();
}

class _ServiceFixScreenState extends State<ServiceFixScreen> with CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;

  final List<File> _fotos = [];
  bool _enviando = false;
  String? _errorNombre;
  String? _errorDescripcion;
  String? _errorFotos;

  /// Campos que el admin marcó. Se resaltan en el formulario.
  late final Set<String> _marcados;

  bool _marcado(String campo) => _marcados.contains(campo);

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.servicio['name'] ?? '');
    _descripcionController =
        TextEditingController(text: widget.servicio['description'] ?? '');
    _marcados = ((widget.servicio['rejected_fields'] as List?) ?? [])
        .map((c) => c.toString())
        .toSet();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _agregarFoto(ImageSource source) async {
    if (_fotos.length >= 5) return;
    await tomarFoto(
      etiqueta: 'SERVICIO',
      source: source,
      onListo: (f) {
        _fotos.add(f);
        _errorFotos = null;
      },
    );
  }

  Future<void> _reenviar() async {
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim();

    // Si el admin marcó las fotos, reenviar sin fotos nuevas devolvería
    // exactamente lo mismo que ya rechazó.
    final errorNombre = nombre.length < 3 ? context.tr('service_name_too_short') : null;
    final errorDescripcion =
        descripcion.length < 10 ? context.tr('service_description_required') : null;
    final errorFotos =
        _marcado('portfolio') && _fotos.isEmpty ? context.tr('portfolio_required') : null;

    setState(() {
      _errorNombre = errorNombre;
      _errorDescripcion = errorDescripcion;
      _errorFotos = errorFotos;
    });

    if (errorNombre != null || errorDescripcion != null || errorFotos != null) return;

    setState(() => _enviando = true);

    try {
      final imagenes = await Future.wait(
        _fotos.map((f) async => base64Encode(await f.readAsBytes())),
      );

      await ServicioApi.reenviar(
        id: widget.servicio['id'],
        nombre: nombre,
        descripcion: descripcion,
        allyEmail: widget.email,
        imagenes: imagenes,
        // Solo se descartan las viejas si el problema eran ellas: si el rechazo
        // fue por el nombre, las pruebas ya revisadas siguen valiendo.
        reemplazarImagenes: _marcado('portfolio') && _fotos.isNotEmpty,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('service_suggested')),
        backgroundColor: _brandColor,
      ));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('connection_error')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nota = widget.servicio['admin_note'] as String?;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(context.tr('fix_service_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (nota != null && nota.isNotEmpty) _bloqueMotivo(nota),
          const SizedBox(height: 20),
          _etiqueta(context.tr('new_service_name'), 'name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nombreController,
            maxLength: 60,
            onChanged: (_) => setState(() => _errorNombre = null),
            decoration: _deco(context.tr('new_service_hint'), _errorNombre, _marcado('name')),
          ),
          const SizedBox(height: 12),
          _etiqueta(context.tr('new_service_description'), 'description'),
          const SizedBox(height: 8),
          TextField(
            controller: _descripcionController,
            maxLength: 200,
            maxLines: 3,
            onChanged: (_) => setState(() => _errorDescripcion = null),
            decoration: _deco(context.tr('new_service_description_hint'), _errorDescripcion,
                _marcado('description')),
          ),
          const SizedBox(height: 20),
          _etiqueta(context.tr('portfolio_title'), 'portfolio'),
          const SizedBox(height: 6),
          Text(
            _marcado('portfolio')
                ? context.tr('fix_photos_replace_help')
                : context.tr('fix_photos_optional_help'),
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5), height: 1.4),
          ),
          const SizedBox(height: 10),
          _grillaFotos(),
          if (_errorFotos != null) ...[
            const SizedBox(height: 6),
            Text(_errorFotos!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _enviando ? null : _reenviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(context.tr('fix_and_resend'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _bloqueMotivo(String nota) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: Colors.red),
              const SizedBox(width: 6),
              Text(context.tr('review_reason_title'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Text(nota,
              style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.75), height: 1.4)),
        ],
      ),
    );
  }

  /// Título de campo con la marca del admin al lado cuando ese campo es el que
  /// hay que corregir.
  Widget _etiqueta(String texto, String campo) {
    return Row(
      children: [
        Text(texto,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
        if (_marcado(campo)) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(context.tr('fix_this_field'),
                style: const TextStyle(
                    fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  InputDecoration _deco(String hint, String? error, bool marcado) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: marcado ? Colors.red : Colors.black26),
    );

    return InputDecoration(
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: Colors.white,
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: marcado ? Colors.red : _brandColor, width: 1.6),
      ),
    );
  }

  Widget _grillaFotos() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._fotos.map((f) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _fotos.remove(f)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration:
                          const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )),
        if (_fotos.length < 5)
          GestureDetector(
            onTap: () => _elegirOrigen(),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _marcado('portfolio') ? Colors.red : Colors.black26),
              ),
              child: Icon(Icons.add_a_photo_outlined,
                  color: _marcado('portfolio') ? Colors.red : Colors.black38),
            ),
          ),
      ],
    );
  }

  void _elegirOrigen() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('camera')),
              onTap: () {
                Navigator.pop(ctx);
                _agregarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _agregarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
