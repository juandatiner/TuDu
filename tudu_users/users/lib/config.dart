import 'dart:io';

/// Configuración de conexión al backend.
class Config {
  // IP inyectada en compilación via --dart-define=LOCAL_IP
  // Si no se pasó, vale '' (cadena vacía).
  static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

  /// Puerto del backend de users
  static const int port = 3000;

  // URL base síncrona que funciona en todas las plataformas de forma confiable.
  static String get baseUrl {
    // 1. Si se inyectó una IP específica (ej. para dispositivo físico), úsala.
    if (_dartDefineIp.isNotEmpty) {
      return 'http://$_dartDefineIp:$port';
    }
    
    // 2. Si no se inyectó IP (ej. corriendo desde VS Code sin configuración especial):
    if (Platform.isAndroid) {
      // El emulador de Android requiere 10.0.2.2 para alcanzar localhost del Mac
      return 'http://10.0.2.2:$port';
    } else {
      // Simulador de iOS, Web y macOS usan localhost directamente
      return 'http://localhost:$port';
    }
  }

  // URL base async (mantenida por compatibilidad si se usa en otros lados)
  static Future<String> getBaseUrl() async {
    return baseUrl;
  }
}
