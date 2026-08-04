import 'api.dart';
import 'auth_store.dart';

/// Flujo de acceso: envío y verificación del código, y alta del usuario.
class AuthApi {
  static Future<void> enviarCodigo(String email) => Api.post('/send-otp', {'email': email});

  /// Verifica el código y guarda la sesión (token de acceso + refresco).
  static Future<void> verificarCodigo({
    required String email,
    required String codigo,
    String? deviceId,
  }) async {
    final data = await Api.post('/verify-otp', {
      'email': email,
      'otp': codigo,
      'device_id': deviceId,
    });

    if (data is Map<String, dynamic>) {
      await AuthStore.saveSession(data);
    }
  }

  /// True si el correo ya tiene cuenta creada.
  static Future<bool> existeUsuario(String email) async {
    final data = await Api.post('/check-user', {'email': email});
    return (data is Map) && data['exists'] == true;
  }

  static Future<void> registrarUsuario({
    required String email,
    required String nombre,
    required String apellido,
  }) =>
      Api.post('/register-user', {
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
      });
}
