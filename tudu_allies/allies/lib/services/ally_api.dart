import 'api.dart';
import 'auth_store.dart';

/// Flujo de acceso del aliado.
class AuthApi {
  /// Pide el código por correo. Devuelve true si el backend lo simuló
  /// (`DEV_MODE`): en ese caso no llega ningún correo y vale el código maestro,
  /// así que la pantalla siguiente lo rellena sola.
  static Future<bool> enviarCodigo(String email) async {
    final data = await Api.post('/send-otp', {'email': email});
    return data is Map && data['dev_mode'] == true;
  }

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

  /// Código ISO del país (CO, MX...) a partir del prefijo de marcación. El
  /// selector de teléfono guarda el prefijo, pero para pintar la bandera pide
  /// el ISO. Si falla, Colombia: es donde opera la app.
  static Future<String> isoDePrefijo(String prefijo) async {
    try {
      final data = await Api.get('/countries/by-dial/$prefijo');
      if (data is Map && data['iso_code'] is String) return data['iso_code'];
    } catch (e) {
      // Sin país no se rompe la pantalla: solo se muestra la bandera por defecto.
    }
    return 'CO';
  }

  /// Teléfono y género. No es perfil público, así que se guarda directo — sin
  /// pasar por la revisión del admin.
  static Future<void> guardarContacto({
    required String email,
    String? phone,
    String? countryCode,
    String? countryName,
    String? phoneNumber,
    String? genero,
  }) =>
      Api.put('/ally-contact', {
        'email': email,
        'phone': phone,
        'country_code': countryCode,
        'country_name': countryName,
        'phone_number': phoneNumber,
        'genero': genero,
      });

  /// Guarda el perfil comercial: se pide una sola vez, entre el KYC y el primer
  /// servicio. La foto va aparte, por [SolicitudFotoAliadoService], porque la
  /// revisa el admin antes de que se vea.
  ///
  /// Devuelve `'pending_review'` cuando el aliado ya tenía perfil publicado: en
  /// ese caso el texto no se aplica, queda a la espera de que el admin lo
  /// apruebe. El perfil inicial sí se guarda directo y responde `'saved'`.
  static Future<String> guardarPerfil({
    required String email,
    required String nombreComercial,
    required String frasePresentacion,
    required String resumen,
  }) async {
    final data = await Api.post('/ally-profile', {
      'email': email,
      'nombre_comercial': nombreComercial,
      'frase_presentacion': frasePresentacion,
      'resumen': resumen,
    });

    if (data is Map && data['status'] is String) return data['status'];
    return 'saved';
  }
}

/// Cambios del perfil comercial pendientes de revisión del admin.
class SolicitudPerfilAliadoService {
  /// La que está en revisión o, si no hay, la última resuelta que el aliado
  /// todavía no vio. `null` cuando no hay nada que mostrar.
  static Future<Map<String, dynamic>?> estado(String email) async {
    final data = await Api.get('/ally-profile-request', query: {'email': email});
    final fila = (data is Map) ? data['request'] : null;
    return fila == null ? null : Map<String, dynamic>.from(fila);
  }

  static Future<void> marcarNotificada(int id) =>
      Api.put('/ally-profile-request/$id/notified');
}

/// Cambios de foto de perfil del aliado.
///
/// Van contra el backend de USERS (3000), no el de aliados: la cola de revisión
/// del admin es una sola y ese es el backend con el Socket.io que le avisa.
/// `Api` enruta solo estas rutas a ese puerto.
class SolicitudFotoAliadoService {
  static Future<void> crear(String email, String imagenBase64) =>
      Api.post('/api/photo-change-request', {
        'email': email,
        'owner_role': 'ally',
        'new_avatar_image': imagenBase64,
      });

  /// La solicitud pendiente, si hay una esperando al admin.
  static Future<Map<String, dynamic>?> pendiente(String email) async {
    final data = await Api.get('/api/photo-change-request/pending',
        query: {'email': email, 'owner_role': 'ally'});
    final fila = (data is Map) ? data['data'] : null;
    return fila == null ? null : Map<String, dynamic>.from(fila as Map);
  }

  /// Una decisión ya tomada que el aliado todavía no vio.
  static Future<Map<String, dynamic>?> sinNotificar(String email) async {
    final data = await Api.get('/api/photo-change-request/unnotified',
        query: {'email': email, 'owner_role': 'ally'});
    final fila = (data is Map) ? data['data'] : null;
    return fila == null ? null : Map<String, dynamic>.from(fila as Map);
  }

  static Future<void> marcarNotificada(int id) =>
      Api.put('/api/photo-change-request/mark-notified/$id');
}

/// Categorías: nivel arriba de los servicios.
class CategoriaApi {
  static Future<List<Map<String, dynamic>>> listar({String estado = 'approved'}) async {
    final data = await Api.get('/categories', query: {'estado': estado});
    final filas = (data is Map) ? data['categories'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// El aliado propone una categoría que no encontró — queda pendiente de revisión.
  static Future<Map<String, dynamic>> sugerir({
    required String nombre,
    required String allyEmail,
  }) async {
    final data = await Api.post('/categories', {'name': nombre, 'ally_email': allyEmail});
    return Map<String, dynamic>.from(data as Map);
  }
}

/// Catálogo de servicios y trabajos disponibles.
class ServicioApi {
  static Future<List<Map<String, dynamic>>> catalogo() async {
    final data = await Api.get('/services');
    final filas = (data is Map) ? data['services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// Servicios aprobados dentro de una categoría.
  static Future<List<Map<String, dynamic>>> porCategoria(int categoryId) async {
    final data = await Api.get('/services', query: {'category_id': '$categoryId'});
    final filas = (data is Map) ? data['services'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

  /// El aliado propone un servicio nuevo dentro de una categoría, con pruebas
  /// (fotos de trabajos hechos, base64). Queda pendiente de revisión.
  static Future<Map<String, dynamic>> crear({
    required String nombre,
    String? descripcion,
    required int categoryId,
    required String allyEmail,
    List<String> imagenes = const [],
  }) async {
    final data = await Api.post('/services', {
      'name': nombre,
      'description': descripcion,
      'category_id': categoryId,
      'ally_email': allyEmail,
      'images': imagenes,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Corrige un servicio rechazado y lo vuelve a mandar a revisión.
  ///
  /// [reemplazarImagenes] borra las pruebas anteriores antes de subir las
  /// nuevas: cuando lo rechazado fueron las fotos, dejarlas no arregla nada.
  static Future<Map<String, dynamic>> reenviar({
    required int id,
    required String nombre,
    String? descripcion,
    required String allyEmail,
    List<String> imagenes = const [],
    bool reemplazarImagenes = false,
  }) async {
    final data = await Api.put('/services/$id/resubmit', {
      'name': nombre,
      'description': descripcion,
      'ally_email': allyEmail,
      'images': imagenes,
      'replace_images': reemplazarImagenes,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Los servicios propios del aliado (categoría, nombre, estado de revisión).
  static Future<List<Map<String, dynamic>>> misPerfiles(String allyEmail) async {
    final data = await Api.get('/ally-service-profiles', query: {'ally_email': allyEmail});
    final filas = (data is Map) ? data['profiles'] : data;
    return List<Map<String, dynamic>>.from(filas ?? []);
  }

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
