import 'api.dart';

/// Verificación del número de teléfono.
///
/// Mismo principio que el correo: el número no se guarda hasta que la persona
/// demuestra que lo controla.
///
/// En desarrollo no se envía ningún SMS y vale el código maestro `123456`. En
/// producción falta enchufar un proveedor de SMS en el backend; hasta entonces,
/// `enviarCodigo` responde 501 fuera de DEV_MODE.
class TelefonoApi {
  static Future<void> enviarCodigo({
    required String email,
    required String telefono,
  }) =>
      Api.post('/users/phone/send-otp', {'email': email, 'phone': telefono});

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
