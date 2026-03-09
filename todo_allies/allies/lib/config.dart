import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

// Configuración de la aplicación
class Config {
  // IMPORTANTE: Cambia esta IP a la de tu computadora en la red local
  // Para obtener tu IP local en Mac: ipconfig getifaddr en0
  // Para obtener tu IP local en Windows: ipconfig
  static const String localIpAddress =
      '10.150.102.86'; // ← CAMBIAR POR TU IP LOCAL

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _isEmulator;

  // Detecta si la app corre en un emulador/simulador
  static Future<bool> get isEmulator async {
    if (_isEmulator != null) return _isEmulator!;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _isEmulator = androidInfo.isPhysicalDevice == false;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _isEmulator = iosInfo.isPhysicalDevice == false;
      } else {
        _isEmulator = false;
      }
    } catch (e) {
      _isEmulator = false;
    }

    return _isEmulator!;
  }

  // URL base del backend - detecta automáticamente el entorno
  static Future<String> getBaseUrl() async {
    final emulator = await isEmulator;

    if (Platform.isAndroid) {
      if (emulator) {
        return 'http://10.0.2.2:3002'; // Emulador Android
      } else {
        return 'http://$localIpAddress:3002'; // Dispositivo físico Android
      }
    } else if (Platform.isIOS) {
      if (emulator) {
        return 'http://localhost:3002'; // Simulador iOS
      } else {
        return 'http://$localIpAddress:3002'; // Dispositivo físico iOS
      }
    } else {
      return 'http://localhost:3002'; // Web, Desktop
    }
  }

  // URL base síncrona (para compatibilidad hacia atrás)
  // NOTA: Usar getBaseUrl() cuando sea posible para detección automática
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://$localIpAddress:3002'; // Por defecto para dispositivo físico
    } else if (Platform.isIOS) {
      return 'http://$localIpAddress:3002'; // Por defecto para dispositivo físico
    } else {
      return 'http://localhost:3002';
    }
  }

  // URLs alternativas para diferentes entornos:
  // - Desarrollo en otra máquina: 'http://10.151.101.23:3002'
  // - Producción: URL de tu servidor desplegado
}
