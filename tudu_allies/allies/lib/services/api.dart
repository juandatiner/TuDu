import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Error devuelto por el backend, con el código que permite distinguir el caso.
///
/// Los códigos los define el backend: `NO_TOKEN`, `TOKEN_EXPIRED`, `FORBIDDEN`,
/// `RATE_LIMITED`, `NOT_FOUND`…
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException(this.statusCode, this.message, {this.code});

  /// True cuando el servidor rechazó la sesión: toca volver al login.
  bool get esSesionInvalida => statusCode == 401;

  /// True cuando se agotó el límite de intentos.
  bool get esLimiteAlcanzado => code == 'RATE_LIMITED';

  @override
  String toString() => message;
}

/// Error de red: sin conexión, servidor caído o tiempo agotado.
class ApiSinConexion implements Exception {
  final String message;
  ApiSinConexion([this.message = 'Sin conexión con el servidor']);

  @override
  String toString() => message;
}

/// Punto único por el que pasan las llamadas al backend.
///
/// Antes cada pantalla construía la URL, serializaba el cuerpo, comprobaba el
/// código de estado y decodificaba el JSON a mano. Eso repetía el mismo bloque
/// de 20 líneas por endpoint y hacía que cada pantalla tratara los errores de
/// forma distinta: unas mostraban el mensaje del servidor, otras uno genérico y
/// otras se lo tragaban.
///
/// La autenticación NO se resuelve aquí: la añade `AuthenticatedClient`, que
/// está instalado con `runWithClient` en `main()` y firma toda petición.
class Api {
  static const Duration _tiempoLimite = Duration(seconds: 15);

  static Uri _uri(String ruta, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${Config.baseUrl}$ruta');
    if (query == null || query.isEmpty) return base;

    return base.replace(queryParameters: {
      ...base.queryParameters,
      ...query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    });
  }

  static Future<dynamic> get(String ruta, {Map<String, dynamic>? query}) =>
      _enviar(() => http.get(_uri(ruta, query)));

  static Future<dynamic> post(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar(() => http.post(
            _uri(ruta),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo ?? {}),
          ));

  static Future<dynamic> put(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar(() => http.put(
            _uri(ruta),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo ?? {}),
          ));

  static Future<dynamic> delete(String ruta, {Map<String, dynamic>? query}) =>
      _enviar(() => http.delete(_uri(ruta, query)));

  static Future<dynamic> _enviar(Future<http.Response> Function() peticion) async {
    late final http.Response respuesta;

    try {
      respuesta = await peticion().timeout(_tiempoLimite);
    } catch (e) {
      throw ApiSinConexion();
    }

    final cuerpo = _decodificar(respuesta.body);

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return cuerpo;
    }

    final mensaje = (cuerpo is Map && cuerpo['error'] is String)
        ? cuerpo['error'] as String
        : 'Error del servidor (${respuesta.statusCode})';

    throw ApiException(
      respuesta.statusCode,
      mensaje,
      code: (cuerpo is Map && cuerpo['code'] is String) ? cuerpo['code'] as String : null,
    );
  }

  static dynamic _decodificar(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      // Algunas respuestas de error de Express llegan como texto plano.
      return {'error': body};
    }
  }
}
