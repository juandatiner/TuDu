import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Guarda los tokens de sesión y los mantiene en memoria para no leer disco en
/// cada petición.
///
/// Son dos:
///  - **acceso**: corto (30 min), viaja en cada petición.
///  - **refresco**: largo (180 días), solo se usa contra `/auth/refresh`.
///
/// Ambos viven en SharedPreferences, así que desinstalar la app los borra y
/// obliga a verificarse de nuevo — que es justo lo que queremos.
class AuthStore {
  static const String _tokenKey = 'auth_token';
  static const String _refreshKey = 'auth_refresh_token';

  static String? _token;
  static String? _refreshToken;

  static String? get token => _token;
  static String? get refreshToken => _refreshToken;
  static bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Se llama una vez al arrancar la app, antes de cualquier petición.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshKey);
  }

  /// Guarda la pareja que devuelve el login o la verificación de OTP.
  static Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data['token'] != null) {
      _token = data['token'];
      await prefs.setString(_tokenKey, _token!);
    }
    if (data['refresh_token'] != null) {
      _refreshToken = data['refresh_token'];
      await prefs.setString(_refreshKey, _refreshToken!);
    }
  }

  static Future<void> clear() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  /// Pide un token de acceso nuevo con el de refresco.
  ///
  /// Devuelve false si el servidor lo rechaza, que es lo que pasa cuando la
  /// sesión fue cerrada desde otro dispositivo: ahí toca volver al login.
  static Future<bool> refresh() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    try {
      // Cliente limpio a propósito: si usara el cliente autenticado, un 401 acá
      // dispararía otro refresco y entraría en bucle.
      final response = await http.Client()
          .post(
            Uri.parse('${Config.adminBaseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await saveSession(jsonDecode(response.body));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refrescando token: $e');
      return false;
    }
  }
}

/// Cliente HTTP que firma toda petición y renueva el token solo.
///
/// Se instala con `runWithClient` en `main()`, así que TODAS las llamadas que
/// ya existen en las pantallas (`http.get`, `http.post`, …) pasan por acá sin
/// tener que tocarlas una por una.
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  /// Se dispara cuando ni el refresco sirve: hay que volver al login.
  static VoidCallback? onUnauthorized;

  /// Evita que varias peticiones en paralelo lancen varios refrescos a la vez.
  static Future<bool>? _refrescoEnCurso;

  static Future<bool> _refrescarUnaVez() {
    _refrescoEnCurso ??= AuthStore.refresh().whenComplete(() {
      _refrescoEnCurso = null;
    });
    return _refrescoEnCurso!;
  }

  void _firmar(http.BaseRequest request) {
    if (AuthStore.hasToken) {
      request.headers['Authorization'] = 'Bearer ${AuthStore.token}';
    }
  }

  /// Rehace la petición desde cero. No se puede reenviar la original: su cuerpo
  /// ya fue consumido al enviarla la primera vez.
  http.BaseRequest _clonar(http.BaseRequest original) {
    if (original is http.Request) {
      final copia = http.Request(original.method, original.url)
        ..headers.addAll(original.headers)
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection
        ..bodyBytes = original.bodyBytes;
      return copia;
    }

    // Peticiones sin cuerpo (GET, DELETE) o multipart: se rehace la base.
    return http.Request(original.method, original.url)
      ..headers.addAll(original.headers);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _firmar(request);

    // El cuerpo hay que retenerlo ANTES de enviar, por si toca reintentar.
    final copia = _clonar(request);

    final response = await _inner.send(request);

    if (response.statusCode != 401) return response;

    // Token vencido: se intenta refrescar y reenviar una sola vez.
    final refrescado = await _refrescarUnaVez();

    if (!refrescado) {
      await AuthStore.clear();
      onUnauthorized?.call();
      return response;
    }

    _firmar(copia);
    return _inner.send(copia);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
