import 'api.dart';
import 'auth_store.dart';

/// Flujo de acceso del aliado.
class AuthApi {
  static Future<void> enviarCodigo(String email) =>
      Api.post('/send-otp', {'email': email});

  /// Verifica el código y guarda la sesión (acceso + refresco).
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
}

/// Perfil del aliado: datos personales, KYC y perfil de servicio.
class AliadoApi {
  /// Estado del aliado. [onLogin] descarta registros abandonados: solo se manda
  /// al entrar a la app, nunca en un refresco de estado.
  static Future<Map<String, dynamic>> estado(String email, {bool onLogin = false}) async {
    final data = await Api.post('/check-ally', {'email': email, 'on_login': onLogin});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> registrar({
    required String email,
    required String nombre,
    required String apellido,
    String? fechaNacimiento,
  }) =>
      Api.post('/register-ally', {
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'fecha_nacimiento': fechaNacimiento,
      });

  /// Sube los tres documentos y deja el KYC en revisión.
  static Future<void> enviarKyc({
    required String email,
    required String cedulaFrente,
    required String cedulaReverso,
    required String selfie,
  }) =>
      Api.post('/ally-kyc', {
        'email': email,
        'cedula_frente': cedulaFrente,
        'cedula_reverso': cedulaReverso,
        'selfie': selfie,
      });

  static Future<void> crearPerfilServicio(Map<String, dynamic> perfil) =>
      Api.post('/ally-service-profile', perfil);
}

/// Catálogo de servicios y trabajos disponibles.
class ServicioApi {
  static Future<List<Map<String, dynamic>>> catalogo() async {
    final data = await Api.get('/services');
    final filas = (data is Map) ? data['services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Crea un servicio nuevo en el catálogo compartido (mínimo 2 caracteres).
  static Future<void> crear(String nombre) => Api.post('/services', {'name': nombre});

  /// Servicios publicados por usuarios y aún sin asignar.
  static Future<List<Map<String, dynamic>>> disponibles() async {
    final data = await Api.get('/services-in-search');
    final filas = (data is Map) ? data['services_in_search'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<List<Map<String, dynamic>>> misServicios(String allyEmail) async {
    final data = await Api.get('/my-services', query: {'ally_email': allyEmail});
    final filas = (data is Map) ? data['my_services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> asignar(int id, String allyEmail) =>
      Api.put('/services-in-search/$id/assign', {'ally_email': allyEmail});

  /// Los estados van en MAYÚSCULAS: 'EN ESPERA', 'EN PROCESO'.
  static Future<void> cambiarEstado(int id, String estado) =>
      Api.put('/services-in-search/$id/status', {'status': estado});
}
