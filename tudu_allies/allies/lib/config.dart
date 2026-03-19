import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

// Configuración de la aplicación
// La IP local se inyecta automáticamente desde el script run-dev.sh
// mediante --dart-define=LOCAL_IP=<ip>
// Si no se inyecta, se detecta en tiempo de compilación vía String.fromEnvironment.
class Config {
  // IP inyectada en compilación via --dart-define=LOCAL_IP
  static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

  /// Puerto del backend de allies
  static const int port = 3002;

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
}
