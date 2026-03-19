import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

// Configuración de la aplicación
class Config {
  // IMPORTANTE: Cambia esta IP a la de tu computadora en la red local
  // Para obtener tu IP local en Mac: ipconfig getifaddr en0
  // Para obtener tu IP local en Windows: ipconfig
  static const String localIpAddress =
      '10.150.100.231'; // ← CAMBIAR POR TU IP LOCAL

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
        return 'http://10.0.2.2:3000'; // Emulador Android
      } else {
        return 'http://$localIpAddress:3000'; // Dispositivo físico Android
      }
    } else if (Platform.isIOS) {
      if (emulator) {
        return 'http://localhost:3000'; // Simulador iOS
      } else {
        return 'http://$localIpAddress:3000'; // Dispositivo físico iOS
      }
    } else {
      return 'http://localhost:3000'; // Web, Desktop
    }
  }

  // Detecta simulador iOS de forma síncrona via variable de entorno
  static bool get _isIosSimulator =>
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_MODEL_IDENTIFIER');

  // URL base síncrona (para compatibilidad hacia atrás)
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Emulador Android
    } else if (_isIosSimulator) {
      return 'http://localhost:3000'; // Simulador iOS
    } else if (Platform.isIOS) {
      return 'http://$localIpAddress:3000'; // Dispositivo físico iOS
    } else {
      return 'http://localhost:3000';
    }
  }

  // URLs alternativas para diferentes entornos:
  // - Desarrollo en otra máquina: 'http://10.151.101.23:3000'
  // - Producción: URL de tu servidor desplegado
}
