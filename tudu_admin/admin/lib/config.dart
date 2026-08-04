import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de conexión al backend.
///
/// Este bloque es IDÉNTICO en las tres apps salvo los puertos: si cambia la
/// forma de resolver la URL, hay que cambiarlo en `tudu_users`, `tudu_allies` y
/// `tudu_admin`. No se extrajo a un paquete compartido porque son tres proyectos
/// Flutter independientes y montar un paquete local para veinte líneas añadía
/// más complejidad de build que la que quitaba.
class Config {
  /// IP inyectada en compilación con `--dart-define=LOCAL_IP`.
  /// Vale '' cuando no se pasó el flag.
  static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

  /// El panel consume el backend de USERS para las solicitudes de cambio de
  /// foto y los sockets: por eso su puerto principal es el 3000, no el 3003.
  static const int port = 3000;

  /// Backend propio de administración: login y CRUD de administradores.
  static const int adminPort = 3003;

  /// URL base del backend de users. Síncrona a propósito: se usa en `build()`.
  static String get baseUrl => _resolverUrl(port);

  /// URL base del backend de administración.
  static String get adminBaseUrl => _resolverUrl(adminPort);

  /// Resuelve la URL según dónde se esté ejecutando la app.
  static String _resolverUrl(int puerto) {
    // 1. IP inyectada: dispositivo físico en la misma red, o `run-dev.sh`.
    if (_dartDefineIp.isNotEmpty) return 'http://$_dartDefineIp:$puerto';

    // 2. El emulador de Android no ve `localhost` del Mac: usa 10.0.2.2.
    if (Platform.isAndroid) return 'http://10.0.2.2:$puerto';

    // 3. Simulador de iOS, web y escritorio hablan con localhost directamente.
    return 'http://localhost:$puerto';
  }

  /// Variante asíncrona, mantenida por compatibilidad con código antiguo.
  static Future<String> getBaseUrl() async => baseUrl;

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
