import 'dart:io';

/// Configuración de conexión al backend.
///
/// Este bloque es IDÉNTICO en las tres apps salvo el puerto: si cambia la forma
/// de resolver la URL, hay que cambiarlo en `tudu_users`, `tudu_allies` y
/// `tudu_admin`. No se extrajo a un paquete compartido porque son tres proyectos
/// Flutter independientes y montar un paquete local para veinte líneas añadía
/// más complejidad de build que la que quitaba.
class Config {
  /// IP inyectada en compilación con `--dart-define=LOCAL_IP`.
  /// Vale '' cuando no se pasó el flag.
  static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

  /// Puerto del backend de users.
  static const int port = 3000;

  /// URL base del backend. Síncrona a propósito: se usa dentro de `build()`.
  static String get baseUrl => _resolverUrl(port);

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
}
