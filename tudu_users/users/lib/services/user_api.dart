import 'api.dart';

/// Perfil del usuario: datos personales, avatar y solicitudes de foto.
class PerfilService {
  /// [lite] omite `avatar_image`, que puede pesar varios megas en base64.
  /// Usarlo siempre que no se vaya a mostrar la foto.
  static Future<Map<String, dynamic>> obtener(String email, {bool lite = false}) async {
    final data = await Api.get('/users/profile/$email', query: lite ? {'lite': 'true'} : null);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> actualizarDatos(Map<String, dynamic> datos) =>
      Api.put('/users/profile/data', datos);

  /// `avatar_image: null` vuelve al avatar de color + icono.
  static Future<void> actualizarAvatar(Map<String, dynamic> datos) =>
      Api.put('/users/profile/avatar', datos);

  static Future<void> eliminarCuenta(String email) => Api.delete('/users/$email');
}

/// Solicitudes de cambio de foto, que revisa un administrador.
class SolicitudFotoService {
  static Future<void> crear(String email, String imagenBase64) =>
      Api.post('/api/user/photo-change-request', {
        'user_email': email,
        'new_avatar_image': imagenBase64,
      });

  static Future<Map<String, dynamic>?> pendiente(String email) async {
    final data = await Api.get('/api/user/photo-change-request/pending',
        query: {'user_email': email});
    final fila = (data is Map) ? data['data'] : null;
    return fila == null ? null : Map<String, dynamic>.from(fila as Map);
  }

  static Future<Map<String, dynamic>?> sinNotificar(String email) async {
    final data = await Api.get('/api/user/photo-change-request/unnotified',
        query: {'user_email': email});
    final fila = (data is Map) ? data['data'] : null;
    return fila == null ? null : Map<String, dynamic>.from(fila as Map);
  }

  static Future<void> marcarNotificada(int id) =>
      Api.put('/api/user/photo-change-request/mark-notified/$id');
}

/// Tarjetas de pago. El backend las guarda enmascaradas.
class TarjetaService {
  /// Este endpoint devuelve el array pelado, no un objeto envolvente.
  static Future<List<Map<String, dynamic>>> listar(String email) async {
    final data = await Api.get('/users/cards/$email');
    return List<Map<String, dynamic>>.from(data ?? []);
  }

  static Future<Map<String, dynamic>> crear(Map<String, dynamic> tarjeta) async {
    final data = await Api.post('/users/cards', tarjeta);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> eliminar(int id) => Api.delete('/users/cards/$id');

  static Future<void> marcarPredeterminada(int id, String email) =>
      Api.put('/users/cards/$id/default', {'user_email': email});
}

/// Direcciones y catálogos geográficos.
class DireccionService {
  static Future<List<Map<String, dynamic>>> listar(String email) async {
    final data = await Api.get('/user-addresses', query: {'user_email': email});
    final filas = (data is Map) ? data['addresses'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> crear(Map<String, dynamic> direccion) =>
      Api.post('/user-addresses', direccion);

  static Future<void> actualizar(int id, Map<String, dynamic> direccion) =>
      Api.put('/user-addresses/$id', direccion);

  static Future<void> eliminar(int id) => Api.delete('/user-addresses/$id');

  static Future<List<Map<String, dynamic>>> departamentos() async {
    final data = await Api.get('/departments');
    final filas = (data is Map) ? data['departments'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<List<Map<String, dynamic>>> ciudades(int departmentId) async {
    final data = await Api.get('/cities', query: {'department_id': departmentId});
    final filas = (data is Map) ? data['cities'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<List<Map<String, dynamic>>> paises() async {
    final data = await Api.get('/countries');
    return List<Map<String, dynamic>>.from(data ?? []);
  }
}

/// Catálogo de servicios, publicación y seguimiento.
class ServicioService {
  static Future<List<Map<String, dynamic>>> catalogo() async {
    final data = await Api.get('/services');
    final filas = (data is Map) ? data['services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> publicar(Map<String, dynamic> servicio) =>
      Api.post('/publish-service', servicio);

  static Future<List<Map<String, dynamic>>> misServicios(String email) async {
    final data = await Api.get('/services-in-search', query: {'user_email': email});
    final filas = (data is Map) ? data['services_in_search'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> eliminar(int id, String email) =>
      Api.delete('/services-in-search/$id', query: {'user_email': email});

  /// Los estados van en MAYÚSCULAS: 'EN ESPERA', 'EN PROCESO'.
  static Future<void> cambiarEstado(int id, String estado) =>
      Api.put('/services-in-search/$id/status', {'status': estado});

  static Future<List<Map<String, dynamic>>> buscar(String consulta) async {
    final data = await Api.get('/search-services', query: {'query': consulta});
    final filas = (data is Map) ? data['services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }
}

/// Categorías — solo las que tienen al menos un servicio aprobado (una
/// categoría vacía no tiene nada que un usuario pueda contratar).
class CategoriaService {
  static Future<List<Map<String, dynamic>>> listar() async {
    final data = await Api.get('/categories');
    final filas = (data is Map) ? data['categories'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Ofertas de aliados dentro de una categoría: un item por (aliado, servicio).
  static Future<List<Map<String, dynamic>>> ofertas(int categoryId) async {
    final data = await Api.get('/category-offers', query: {'category_id': '$categoryId'});
    final filas = (data is Map) ? data['offers'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }
}

/// Historial de búsquedas (las últimas 10).
class HistorialService {
  /// El backend expone la columna `query` bajo el nombre `search_query`.
  static Future<List<Map<String, dynamic>>> listar(String email) async {
    final data = await Api.get('/search-history', query: {'user_email': email});
    final filas = (data is Map) ? data['search_history'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  static Future<void> guardar(String email, String consulta) =>
      Api.post('/search-history', {'user_email': email, 'search_query': consulta});

  static Future<void> eliminar(int id) => Api.delete('/search-history/$id');
}
