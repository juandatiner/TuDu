import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';

/// Reutilizable en cualquier pantalla que necesite fotos (KYC, pruebas de un
/// servicio). Por defecto solo cámara — para KYC eso es a propósito, no se
/// negocia — pero cada llamado puede pedir galería (`source`) para casos
/// donde sí tiene sentido, como el portafolio de un servicio.
/// En simulador/emulador no hay cámara real: en vez de intentar abrirla y
/// fallar, se genera una foto de prueba y se asigna directo, como si la
/// persona ya la hubiera tomado. En un dispositivo físico esa rama nunca se
/// activa y siempre pasa por la cámara o galería real.
mixin CameraCaptureMixin<T extends StatefulWidget> on State<T> {
  bool esDispositivoFisico = true;

  Future<void> detectarDispositivo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      bool esFisico = true;
      if (Platform.isIOS) {
        esFisico = (await deviceInfo.iosInfo).isPhysicalDevice;
      } else if (Platform.isAndroid) {
        esFisico = (await deviceInfo.androidInfo).isPhysicalDevice;
      }
      if (mounted) setState(() => esDispositivoFisico = esFisico);
    } catch (_) {
      // Si la detección falla, se queda en true: comportamiento de producción.
    }
  }

  Future<void> tomarFoto({
    required String etiqueta,
    required void Function(File) onListo,
    CameraDevice camaraPreferida = CameraDevice.rear,
    double maxWidth = 1200,
    ImageSource source = ImageSource.camera,
  }) async {
    if (!esDispositivoFisico) {
      final foto = await _generarFotoPruebaSimulador(etiqueta);
      if (!mounted) return;
      setState(() => onListo(foto));
      return;
    }

    final picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: camaraPreferida,
        imageQuality: 70,
        maxWidth: maxWidth,
      );
      if (picked != null) {
        setState(() => onListo(File(picked.path)));
      }
    } catch (e) {
      mostrarErrorCamara();
    }
  }

  Future<File> _generarFotoPruebaSimulador(String etiqueta) async {
    const width = 800.0;
    const height = 600.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF78BF32),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$etiqueta\n(foto de prueba — simulador)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 80);
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, (height - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp('tudu_foto_');
    final file = File(
      '${dir.path}/foto_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  void mostrarErrorCamara() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('camera_error'))),
    );
  }
}
