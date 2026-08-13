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
///
/// El simulador no tiene cámara: pedirla ahí falla, así que se genera una foto
/// de prueba y se asigna directo. La galería **sí** existe en el simulador (el
/// carrete trae imágenes de muestra), así que esa siempre abre el selector
/// real: si no, era imposible probar el flujo de elegir una foto propia.
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

  /// [noRepetirDe] son las fotos ya elegidas: si la nueva es la misma imagen,
  /// se descarta y se avisa por [onRepetida] en vez de agregarla. Elegir dos
  /// veces la misma del carrete da rutas distintas, así que no alcanza con
  /// comparar el path — se compara el contenido.
  Future<void> tomarFoto({
    required String etiqueta,
    required void Function(File) onListo,
    CameraDevice camaraPreferida = CameraDevice.rear,
    double maxWidth = 1200,
    ImageSource source = ImageSource.camera,
    List<File>? noRepetirDe,
    VoidCallback? onRepetida,
  }) async {
    // Solo la cámara necesita el atajo: la galería del simulador funciona.
    if (!esDispositivoFisico && source == ImageSource.camera) {
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
      if (picked == null) return;

      final archivo = File(picked.path);

      if (noRepetirDe != null && await esFotoRepetida(noRepetirDe, archivo)) {
        if (!mounted) return;
        onRepetida?.call();
        return;
      }

      if (!mounted) return;
      setState(() => onListo(archivo));
    } catch (e) {
      mostrarErrorCamara();
    }
  }

  /// True si [nueva] es exactamente la misma imagen que alguna de [existentes].
  ///
  /// Comparación byte a byte: sin dependencia de hashing (`crypto` acá es
  /// transitiva) y con un máximo de 5 fotos el costo no se nota. Se descarta
  /// por tamaño antes de comparar, que resuelve casi todos los casos de una.
  Future<bool> esFotoRepetida(List<File> existentes, File nueva) async {
    final bytesNueva = await nueva.readAsBytes();

    for (final foto in existentes) {
      if (await foto.length() != bytesNueva.length) continue;

      final bytes = await foto.readAsBytes();
      var iguales = true;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != bytesNueva[i]) {
          iguales = false;
          break;
        }
      }
      if (iguales) return true;
    }

    return false;
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
