import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración de la aplicación
class Config {
  // IMPORTANTE: Cambia esta IP a la de tu computadora en la red local
  static const String localIpAddress =
      '10.150.100.231'; // ← CAMBIAR POR TU IP LOCAL

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _isEmulator;

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

  static bool get _isIosSimulator =>
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_MODEL_IDENTIFIER');

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

  // Colores de la aplicación (identidad de TuDu)
  static const Color backgroundColor = Color(0xFFF4F2F2);
  static const Color primaryColor = Color(0xFF78BF32);
  static const Color textColor = Color(0xFF78BF32);
  static const Color secondaryColor = Color(0xFF595959);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF000000);
  static const Color redColor = Color(0xFFF44336);
}

void hideSystemUI() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
}

void showSystemUI() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values);
}

Future<void> setOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboardingCompleted', true);
}

Future<bool> hasOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboardingCompleted') ?? false;
}
