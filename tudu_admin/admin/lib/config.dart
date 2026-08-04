import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración de la aplicación
class Config {
  // IP inyectada en compilación via --dart-define=LOCAL_IP
  static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

  /// El backend está actualmente expuesto a través de tudu_users en el puerto 3000
  static const int port = 3000;

  // URL base síncrona que funciona en todas las plataformas de forma confiable.
  static String get baseUrl {
    if (_dartDefineIp.isNotEmpty) {
      return 'http://$_dartDefineIp:$port';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$port'; // Emulador Android
    } else {
      return 'http://localhost:$port'; // Simulador iOS, Web, Desktop
    }
  }

  static Future<String> getBaseUrl() async {
    return baseUrl;
  }

  /// Puerto del backend propio de administración (login y CRUD de admins).
  /// El resto del panel consume el backend de users en el 3000.
  static const int adminPort = 3003;

  static String get adminBaseUrl {
    if (_dartDefineIp.isNotEmpty) {
      return 'http://$_dartDefineIp:$adminPort';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$adminPort';
    }
    return 'http://localhost:$adminPort';
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
