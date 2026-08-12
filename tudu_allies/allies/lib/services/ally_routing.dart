import 'package:flutter/material.dart';

import 'ally_api.dart';
import '../screens/ally_profile_setup_screen.dart';
import '../screens/home_screen.dart';
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
      final data = await AliadoApi.estado(email, onLogin: onLogin);

      if (data['exists'] == true) {
        return AllyHomeScreen(allyEmail: email);
      }

      return screenForPartial(
        data['partial'],
        email,
        kycStatus: data['kyc_status'],
        motivoRechazoKyc: data['kyc_reviewer_note'],
        ally: data['ally'] is Map ? Map<String, dynamic>.from(data['ally']) : null,
      );
    } catch (e) {
      debugPrint('Error resolviendo destino del aliado: $e');
      return RegistrationScreen(email: email);
    }
  }

  /// Traduce el `partial` que devuelve el backend a una pantalla.
  static Widget screenForPartial(String? partial, String email,
      {String? kycStatus, String? motivoRechazoKyc, Map<String, dynamic>? ally}) {
    switch (partial) {
      case 'profile':
        // Perfil comercial: va entre el KYC y el primer servicio, y se pide una
        // sola vez porque describe al aliado, no a cada servicio.
        return AllyProfileSetupScreen(email: email, perfil: ally);
      case 'kyc_pending':
        // Documentos enviados y en revisión: puede navegar y ver todo, pero
        // el Home se lo recuerda con un aviso y le bloquea tomar solicitudes.
        return AllyHomeScreen(allyEmail: email, kycStatus: kycStatus ?? 'submitted');
      case 'kyc':
        // Con motivo cuando viene de un rechazo: la pantalla lo muestra arriba.
        return KycVerificationScreen(email: email, motivoRechazo: motivoRechazoKyc);
      case 'service':
        return ServiceSetupScreen(email: email);
      case 'personal':
      default:
        return RegistrationScreen(email: email);
    }
  }
}
