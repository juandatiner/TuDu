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
  /// Ruta base de la cola: la de aliados vive en el backend 3002 y la de
  /// clientes en el de users (3000). `Api` enruta sola según el prefijo.
  static const rutaAliados = '/api/admin/kyc';
  static const rutaUsuarios = '/api/admin/user-kyc';

  /// [estado] `submitted` para los pendientes, `todos` para el historial.
  static Future<List<Map<String, dynamic>>> listar({
    String estado = 'submitted',
    String ruta = rutaAliados,
  }) async {
    final data = await Api.get(ruta, query: {'estado': estado});
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Detalle con los tres documentos. Las URLs vienen firmadas y caducan en una
  /// hora: el bucket de KYC es privado.
  static Future<Map<String, dynamic>> detalle(String email,
      {String ruta = rutaAliados}) async {
    final data = await Api.get('$ruta/$email');
    return Map<String, dynamic>.from((data as Map)['data'] ?? {});
  }

  /// Al rechazar, el motivo es obligatorio: el aliado necesita saber qué corregir.
  static Future<void> revisar(String email, String estado,
          {String? motivo, String ruta = rutaAliados}) =>
      Api.put('$ruta/$email', {'status': estado, 'note': motivo});
}

/// Revisión de los cambios que un aliado hace a su perfil comercial. Vive en
/// el backend de aliados (3002), dueño de la tabla `allies`.
class CambiosPerfilAdminApi {
  /// [estado] `pending` (por defecto) o `todos` para el historial. Cada fila
  /// trae el texto propuesto y, en `actual`, el que está publicado hoy.
  static Future<List<Map<String, dynamic>>> listar({String estado = 'pending'}) async {
    final data = await Api.get('/api/admin/profile-changes', query: {'estado': estado});
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Al aprobar, el backend copia el texto al perfil del aliado y se lo avisa
  /// por socket. Al rechazar, el motivo es obligatorio.
  static Future<void> revisar(int id, String estado, {String? motivo}) =>
      Api.put('/api/admin/profile-changes/$id', {
        'status': estado,
        'rejection_reason': motivo,
      });
}

/// Revisión de servicios propuestos por aliados (categoría + nombre +
/// descripción + pruebas). Vive en el backend de aliados (3002), mismo dueño
/// que la revisión de KYC.
class ServiciosAdminApi {
  /// [estado] `pending` para los pendientes (por defecto), `todos` para el historial.
  static Future<List<Map<String, dynamic>>> listar({String estado = 'pending'}) async {
    final data = await Api.get('/api/admin/services', query: {'estado': estado});
    final filas = (data is Map) ? data['data'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Aprobar, rechazar o corregir (nombre/descripción/categoría) un servicio
  /// propuesto. Al rechazar, el motivo es obligatorio.
  /// [campos] marca qué hay que corregir (`name`, `description`, `portfolio`,
  /// `category`): el aliado ve resaltado eso mismo en su formulario. Obligatorio
  /// al rechazar.
  static Future<void> revisar(
    int id,
    String estado, {
    String? nombre,
    String? descripcion,
    int? categoryId,
    String? motivo,
    List<String>? campos,
  }) =>
      Api.put('/api/admin/services/$id', {
        'status': estado,
        'name': nombre,
        'description': descripcion,
        'category_id': categoryId,
        'admin_note': motivo,
        'rejected_fields': campos,
      });

  /// Borra una prueba concreta del portafolio: deja aprobar un servicio bueno
  /// al que se le coló una foto que no corresponde.
  static Future<void> borrarFoto(int id) => Api.delete('/api/admin/portfolio-items/$id');
}

/// Revisión de categorías propuestas por aliados. Decisión independiente de
/// la del servicio.
class CategoriasAdminApi {
  /// Categorías aprobadas — para el buscador de "redirigir a categoría existente".
  static Future<List<Map<String, dynamic>>> listar() async {
    final data = await Api.get('/categories', query: {'estado': 'approved'});
    final filas = (data is Map) ? data['categories'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> revisar(int id, String estado, {String? nombre, String? motivo}) =>
      Api.put('/api/admin/categories/$id', {
        'status': estado,
        'name': nombre,
        'admin_note': motivo,
      });

  /// El admin crea una categoría directo — entra aprobada, sin revisión.
  static Future<Map<String, dynamic>> crear(String nombre) async {
    final data = await Api.post('/api/admin/categories', {'name': nombre});
    return Map<String, dynamic>.from((data as Map)['data'] ?? {});
  }
}
