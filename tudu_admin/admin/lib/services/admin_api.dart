import 'api.dart';
import 'auth_store.dart';

/// Acceso al panel de administración (backend 3003).
class AdminAuthApi {
  /// Valida las credenciales contra el servidor y guarda la sesión.
  ///
  /// Devuelve los datos del administrador. Antes esta comprobación se hacía
  /// dentro de la propia app comparando texto fijo, así que el servidor ni se
  /// enteraba de quién entraba.
  static Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    final data = await Api.post('/api/admin/login', {
      'username': usuario,
      'password': password,
    });

    if (data is Map<String, dynamic>) {
      await AuthStore.saveSession(data);
      return Map<String, dynamic>.from(data['data'] ?? {});
    }
    return {};
  }
}

/// Solicitudes de cambio de foto. Viven en el backend de users (3000).
class SolicitudFotoAdminApi {
  static Future<List<Map<String, dynamic>>> listar() async {
    final data = await Api.get('/api/admin/photo-change-requests');
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> marcarLeida(int id) =>
      Api.put('/api/admin/photo-change-requests/$id/read');

  /// [estado] es 'approved' o 'rejected'. Al aprobar, el backend copia la foto
  /// al perfil del usuario y lo avisa por socket.
  static Future<void> resolver(int id, String estado, {String? motivoRechazo}) =>
      Api.put('/api/admin/photo-change-requests/$id', {
        'status': estado,
        'rejection_reason': motivoRechazo,
      });
}

/// Gestión de cuentas de administrador (backend 3003).
class AdminsApi {
  static Future<List<Map<String, dynamic>>> listar() async {
    final data = await Api.get('/api/admins');
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> crear(Map<String, dynamic> admin) => Api.post('/api/admins', admin);

  static Future<void> actualizar(int id, Map<String, dynamic> admin) =>
      Api.put('/api/admins/$id', admin);

  static Future<void> eliminar(int id) => Api.delete('/api/admins/$id');

  static Future<void> cambiarPassword(int id, String actual, String nueva) =>
      Api.put('/api/admins/$id/change-password', {
        'currentPassword': actual,
        'newPassword': nueva,
      });
}

/// Revisión de la verificación de identidad de los aliados.
/// Vive en el backend de aliados (3002), que es el dueño de la tabla `allies`.
class KycAdminApi {
  /// [estado] `submitted` para los pendientes, `todos` para el historial.
  static Future<List<Map<String, dynamic>>> listar({String estado = 'submitted'}) async {
    final data = await Api.get('/api/admin/kyc', query: {'estado': estado});
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Detalle con los tres documentos. Las URLs vienen firmadas y caducan en una
  /// hora: el bucket de KYC es privado.
  static Future<Map<String, dynamic>> detalle(String email) async {
    final data = await Api.get('/api/admin/kyc/$email');
    return Map<String, dynamic>.from((data as Map)['data'] ?? {});
  }

  /// Al rechazar, el motivo es obligatorio: el aliado necesita saber qué corregir.
  static Future<void> revisar(String email, String estado, {String? motivo}) =>
      Api.put('/api/admin/kyc/$email', {'status': estado, 'note': motivo});
}
