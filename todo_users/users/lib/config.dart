import 'dart:io';

// Configuración de la aplicación
class Config {
  // URL base del backend
  // Se determina automáticamente según la plataforma
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Para Android emulator
    } else if (Platform.isIOS) {
      return 'http://localhost:3000'; // Para iOS simulator
    } else {
      return 'http://localhost:3000'; // Para otros (web, desktop)
    }
  }

  // URLs alternativas para diferentes entornos:
  // - Desarrollo en otra máquina: 'http://10.151.101.23:3000'
  // - Producción: URL de tu servidor desplegado
}
