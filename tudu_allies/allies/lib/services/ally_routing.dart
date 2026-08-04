import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../screens/home_screen.dart';
import '../screens/kyc_pending_screen.dart';
import '../screens/kyc_verification_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/service_setup_screen.dart';

/// Punto único que decide a qué pantalla va un aliado según lo que le falta.
///
/// Vive aparte para que todas las entradas a la app (login con sesión activa,
/// éxito de OTP, refresco desde la pantalla de espera) resuelvan el destino con
/// la misma lógica. Antes cada pantalla decidía por su cuenta y un aliado sin
/// KYC podía terminar en el formulario de datos personales otra vez.
class AllyRouting {
  /// Consulta `/check-ally` y devuelve la pantalla que corresponde.
  ///
  /// Nunca devuelve `RegistrationScreen` si el aliado ya tiene nombre y
  /// apellido guardados: el backend solo responde `partial: 'personal'`
  /// cuando esos datos faltan de verdad.
  /// [onLogin] marca que esto es una entrada a la app, no un refresco. Con eso
  /// el backend descarta registros abandonados (datos a medias sin cédula
  /// enviada) para que el aliado arranque limpio en vez de caer en un paso
  /// intermedio que nunca completó.
  static Future<Widget> resolveDestination(String email,
      {bool onLogin = false}) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/check-ally'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'on_login': onLogin}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return RegistrationScreen(email: email);
      }

      final data = jsonDecode(response.body);
      if (data['exists'] == true) {
        return AllyHomeScreen(allyEmail: email);
      }

      return screenForPartial(data['partial'], email);
    } catch (e) {
      debugPrint('Error resolviendo destino del aliado: $e');
      return RegistrationScreen(email: email);
    }
  }

  /// Traduce el `partial` que devuelve el backend a una pantalla.
  static Widget screenForPartial(String? partial, String email) {
    switch (partial) {
      case 'kyc_pending':
        // Documentos enviados y en revisión: solo esperar, jamás repetir datos.
        return KycPendingScreen(email: email);
      case 'kyc':
        return KycVerificationScreen(email: email);
      case 'service':
        return ServiceSetupScreen(email: email);
      case 'personal':
      default:
        return RegistrationScreen(email: email);
    }
  }
}
