import 'api.dart';

/// Verificación del número de teléfono.
///
/// Mismo principio que el correo: el número no se guarda hasta que la persona
/// demuestra que lo controla.
///
/// Con Twilio configurado en el backend llega un SMS real. Sin credenciales y
/// en DEV_MODE no se envía nada y vale el código maestro `123456`; sin
/// credenciales y sin DEV_MODE, `enviarCodigo` responde 501.
class TelefonoApi {
  /// Devuelve true si el backend simuló el envío (modo desarrollo): en ese caso
  /// no llega ningún SMS y hay que usar el código maestro.
  static Future<bool> enviarCodigo({
    required String email,
    required String telefono,
  }) async {
    final data =
        await Api.post('/users/phone/send-otp', {'email': email, 'phone': telefono});
    return data is Map && data['dev_mode'] == true;
  }

  /// Comprueba el código y, si es correcto, guarda el teléfono ya verificado.
  static Future<String> verificarCodigo({
    required String email,
    required String codigo,
    required String countryCode,
    required String phoneNumber,
    String? countryName,
  }) async {
    final data = await Api.post('/users/phone/verify-otp', {
      'email': email,
      'otp': codigo,
      'country_code': countryCode,
      'country_name': countryName,
      'phone_number': phoneNumber,
    });

    return (data is Map && data['phone'] != null) ? data['phone'] as String : '';
  }
}
