import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config.dart';

/// Servicio para gestionar las sesiones de dispositivo
/// Maneja el registro, verificación y cierre de sesiones
class SessionService extends ChangeNotifier {
  static const String _deviceIdKey = 'device_id';
  static const String _userEmailKey = 'logged_user_email';
  static const String _sessionActiveKey = 'session_active';

  String? _deviceId;
  String? _deviceInfo;
  String? _userEmail;
  bool _isSessionActive = false;
  bool _isInitialized = false;

  // Getters
  String? get deviceId => _deviceId;
  String? get deviceInfo => _deviceInfo;
  String? get userEmail => _userEmail;
  bool get isSessionActive => _isSessionActive;
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de sesión
  /// Obtiene o genera un ID único del dispositivo
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Obtener o generar device_id único
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null) {
      _deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }

    // Obtener información del dispositivo
    _deviceInfo = await _getDeviceInfo();

    // Obtener email del usuario logueado
    _userEmail = prefs.getString(_userEmailKey);

    // Verificar si hay sesión activa guardada
    _isSessionActive = prefs.getBool(_sessionActiveKey) ?? false;

    _isInitialized = true;
    notifyListeners();
  }

  /// Genera un ID único para el dispositivo
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // Usar androidId si está disponible, sino generar uno basado en características del dispositivo
      return 'android_${androidInfo.id}_${androidInfo.model.hashCode}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // En iOS usamos el identifierForVendor
      return 'ios_${iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch}';
    } else {
      // Para web u otras plataformas
      return 'other_${DateTime.now().millisecondsSinceEpoch}_${_deviceInfo.hashCode}';
    }
  }

  /// Obtiene información detallada del dispositivo
  Future<String> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return jsonEncode({
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return jsonEncode({
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        });
      } else {
        return jsonEncode({
          'platform': 'other',
          'info': 'Unknown device',
        });
      }
    } catch (e) {
      return jsonEncode({
        'platform': 'unknown',
        'error': e.toString(),
      });
    }
  }

  /// Verifica si el dispositivo necesita verificación
  /// Retorna true si necesita verificación (nuevo dispositivo o sesión desactivada)
  Future<Map<String, dynamic>> checkSession(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/device-session/check'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'device_id': _deviceId,
              'device_info': _deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'requires_verification': data['requires_verification'] ?? true,
          'session_active': data['session_active'] ?? false,
          'has_other_sessions': data['has_other_sessions'] ?? false,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body)['error'];
        return {
          'success': false,
          'error': error ?? 'Error verificando sesión',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Registra una nueva sesión después de la verificación
  /// Desactiva todas las demás sesiones del usuario
  Future<bool> registerSession(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/device-session/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'device_id': _deviceId,
              'device_info': _deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _userEmail = email;
        _isSessionActive = true;

        // Guardar en preferencias
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userEmailKey, email);
        await prefs.setBool(_sessionActiveKey, true);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registrando sesión: $e');
      return false;
    }
  }

  /// Verifica si la sesión actual sigue activa
  /// Útil para polling y detectar si otro dispositivo cerró esta sesión
  Future<bool> verifySessionStatus() async {
    if (_userEmail == null || _deviceId == null) return false;

    try {
      final response = await http
          .get(
            Uri.parse(
                '${Config.baseUrl}/device-session/status?email=$_userEmail&device_id=$_deviceId'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isActive = data['is_active'] ?? false;

        if (!isActive && _isSessionActive) {
          // La sesión fue cerrada desde otro dispositivo
          await _handleSessionClosed();
        }

        return isActive;
      }
      return false;
    } catch (e) {
      debugPrint('Error verificando estado de sesión: $e');
      return _isSessionActive; // Mantener estado actual si hay error de conexión
    }
  }

  /// Cierra la sesión actual
  Future<void> logout() async {
    if (_userEmail == null || _deviceId == null) return;

    try {
      await http
          .post(
            Uri.parse('${Config.baseUrl}/device-session/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _userEmail,
              'device_id': _deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error cerrando sesión en servidor: $e');
    }

    await _clearLocalSession();
  }

  /// Maneja cuando la sesión es cerrada desde otro dispositivo
  Future<void> _handleSessionClosed() async {
    await _clearLocalSession();
    notifyListeners();
  }

  /// Limpia la sesión local
  Future<void> _clearLocalSession() async {
    _isSessionActive = false;
    _userEmail = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userEmailKey);
    await prefs.remove(_sessionActiveKey);

    notifyListeners();
  }

  /// Obtiene todas las sesiones activas del usuario
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    if (_userEmail == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse(
                '${Config.baseUrl}/device-session/list?email=$_userEmail'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo sesiones: $e');
      return [];
    }
  }

  /// Cierra todas las sesiones excepto la actual
  Future<int> closeOtherSessions() async {
    if (_userEmail == null || _deviceId == null) return 0;

    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/device-session/close-others'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _userEmail,
              'device_id': _deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['closed_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error cerrando otras sesiones: $e');
      return 0;
    }
  }

  /// Guarda el email del usuario logueado
  Future<void> setUserEmail(String email) async {
    _userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
    notifyListeners();
  }

  /// Limpia todos los datos de sesión (para logout completo)
  Future<void> clearAllSessionData() async {
    await _clearLocalSession();
  }
}
