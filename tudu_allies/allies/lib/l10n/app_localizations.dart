import 'package:flutter/material.dart';

/// Traducciones de la app de aliados (español e inglés).
///
/// Antes la app estaba fijada a español (`locale: Locale('es','CO')` en
/// `main.dart`) y todos los textos estaban escritos a mano en cada pantalla, así
/// que en un dispositivo en inglés igual salía todo en español. Ahora el idioma
/// sale del sistema y los textos viven acá, con el mismo mecanismo que la app de
/// usuarios (`translate` / `t` / `context.tr`).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _valores = {
    'es': {
      // Generales
      'continue_button': 'Continuar',
      'accept': 'Aceptar',
      'confirm': 'Confirmar',
      'close_session': 'Cerrar sesión',
      'connection_error': 'Error de conexión',
      'connection_error_check': 'Error de conexión. Verifica tu conexión a internet.',

      // Validación
      'field_required': 'Campo obligatorio',
      'complete_all_fields': 'Completa todos los campos marcados en rojo',
      'upload_marked_documents': 'Sube los documentos marcados en rojo',

      // Onboarding
      'allies': 'Aliados',
      'onboarding_tagline': 'Tu negocio, nuestra plataforma.',

      // Login
      'enter_email': 'Ingresa tu correo electrónico',
      'invalid_email': 'Ingresa un correo electrónico válido',
      'continue_google': 'Continuar con Google',
      'continue_facebook': 'Continuar con Facebook',
      'social_soon': 'Próximamente',

      // OTP
      'otp_title': 'Verificación',
      'otp_subtitle': 'Ingresa el código de 6 dígitos enviado a',
      'otp_incomplete': 'Por favor ingresa el código completo de 6 dígitos',
      'otp_resent': 'Código OTP reenviado',
      'otp_resend': 'Reenviar código',
      'otp_resend_in': 'Reenviar en',
      'otp_change_email': 'Cambiar correo electrónico',
      'verify': 'Verificar',
      'verification_success': '¡Verificación exitosa!',
      'redirecting': 'Redirigiendo...',

      // Pasos
      'step_data': 'Datos',
      'step_verification': 'Verificación',
      'step_service': 'Servicio',

      // Registro
      'personal_data': 'Datos personales',
      'tell_us_about_you': 'Cuéntanos un poco sobre ti',
      'first_name': 'Nombre',
      'last_name': 'Apellidos',
      'birth_date': 'Fecha de nacimiento',
      'must_be_18': 'Debes ser mayor de 18 años para ser aliado',
      'must_be_18_short': 'Debes ser mayor de 18 años',

      // KYC
      'identity_verification': 'Verificación de identidad',
      'kyc_intro':
          'Necesitamos confirmar que eres tú.\nTus documentos son revisados por nuestro equipo.',
      'id_front': 'Cédula – Parte frontal',
      'id_front_hint': 'Asegúrate de que sea legible',
      'id_back': 'Cédula – Parte trasera',
      'id_back_hint': 'Con todos los datos visibles',
      'selfie': 'Selfie de verificación',
      'selfie_hint': 'Se tomará con tu cámara frontal.\nNo se puede adjuntar de galería.',
      'camera_only': 'Solo cámara',
      'tap_to_add': 'Toca para agregar',
      'add_photo': 'Agregar foto',
      'use_camera': 'Usar cámara',
      'choose_gallery': 'Elegir de galería',
      'photo_added': '¡Foto agregada! Toca para cambiarla',
      'selfie_taken': '¡Selfie tomada! Toca para repetirla',
      'documents_safe':
          'Tus documentos están cifrados y seguros. Solo nuestro equipo de verificación los revisa.',

      // KYC pendiente
      'account_under_review': 'Tu cuenta está siendo verificada',
      'kyc_pending_body':
          'Ya recibimos tus documentos. Un administrador los está revisando y te avisaremos apenas quede aprobada.\n\nNo necesitas volver a ingresar tus datos.',
      'refresh_status': 'Actualizar estado',
      'still_under_review': 'Tu verificación sigue en revisión',
      'status_check_failed': 'No se pudo consultar el estado. Revisa tu conexión.',

      // Perfil de servicio
      'your_star_service': 'Tu servicio estrella',
      'service_setup_intro':
          'Define el primer servicio con el que aparecerás en la plataforma.',
      'service_category': 'Categoría del servicio',
      'search_service_hint': 'Busca tu tipo de servicio...',
      'service_not_found': 'No encontré mi servicio',
      'new_service_name': 'Nombre del nuevo servicio',
      'new_service_hint': 'Ej: Carpintería a domicilio',
      'create_this_service': 'Crear este servicio',
      'select_or_create_service': 'Selecciona o crea un servicio',
      'service_created': 'creado exitosamente',
      'your_business_name': 'Tu nombre o nombre de negocio',
      'commercial_name': 'Nombre comercial',
      'commercial_name_hint': 'Ej: Juan López / Electricidad López',
      'pitch_title': 'Frase de presentación',
      'pitch_help': 'Muy corta: di en una línea qué haces.',
      'pitch_label': 'Frase corta',
      'pitch_hint': 'Ej: Especialista en instalaciones eléctricas residenciales',
      'summary_title': 'Resumen de tu experiencia',
      'summary_help':
          'Describe brevemente tus habilidades en este servicio. Este texto aparecerá en tu perfil.',
      'summary_label': 'Resumen profesional',
      'summary_hint':
          'Cuéntanos qué sabes hacer, tu experiencia, y por qué los clientes deben elegirte...',
      'service_setup_tip':
          '💡 Recuerda: más adelante podrás crear más servicios. Enfócate en este servicio únicamente.',
      'start_as_ally': '¡Comenzar como Aliado!',

      // Home
      'hello_ally': '¡Hola, Aliado! 👋',
      'available_requests': '📋 Solicitudes disponibles',
      'no_requests': 'No hay solicitudes disponibles en este momento.\n¡Vuelve más tarde!',
      'home': 'Inicio',
      'my_services': 'Mis servicios',
      'my_services_title': 'Mis Servicios',
      'messages': 'Mensajes',
      'no_messages':
          'No tienes mensajes aún.\nAquí aparecerán tus conversaciones con clientes.',
      'profile': 'Perfil',
      'my_data': 'Mis datos',
      'my_ratings': 'Mis calificaciones',
      'wallet': 'Billetera',
      'support': 'Soporte',
      'add': 'Agregar',
      'no_active_services':
          'Aún no tienes servicios activos.\nTu servicio inicial está siendo revisado.',
      'pending_verification': 'Verificación Pendiente',
      'verification_in_review': 'Verificación en revisión',

      // Dashboard
      'available_services': 'Servicios disponibles:',
    },
    'en': {
      // General
      'continue_button': 'Continue',
      'accept': 'Accept',
      'confirm': 'Confirm',
      'close_session': 'Log out',
      'connection_error': 'Connection error',
      'connection_error_check': 'Connection error. Check your internet connection.',

      // Validation
      'field_required': 'Required field',
      'complete_all_fields': 'Please complete all the fields marked in red',
      'upload_marked_documents': 'Upload the documents marked in red',

      // Onboarding
      'allies': 'Allies',
      'onboarding_tagline': 'Your business, our platform.',

      // Login
      'enter_email': 'Enter your email address',
      'invalid_email': 'Enter a valid email address',
      'continue_google': 'Continue with Google',
      'continue_facebook': 'Continue with Facebook',
      'social_soon': 'Coming soon',

      // OTP
      'otp_title': 'Verification',
      'otp_subtitle': 'Enter the 6-digit code sent to',
      'otp_incomplete': 'Please enter the full 6-digit code',
      'otp_resent': 'OTP code resent',
      'otp_resend': 'Resend code',
      'otp_resend_in': 'Resend in',
      'otp_change_email': 'Change email address',
      'verify': 'Verify',
      'verification_success': 'Verification successful!',
      'redirecting': 'Redirecting...',

      // Steps
      'step_data': 'Details',
      'step_verification': 'Verification',
      'step_service': 'Service',

      // Registration
      'personal_data': 'Personal details',
      'tell_us_about_you': 'Tell us a bit about yourself',
      'first_name': 'First name',
      'last_name': 'Last name',
      'birth_date': 'Date of birth',
      'must_be_18': 'You must be 18 or older to become an ally',
      'must_be_18_short': 'You must be 18 or older',

      // KYC
      'identity_verification': 'Identity verification',
      'kyc_intro':
          'We need to confirm it is really you.\nYour documents are reviewed by our team.',
      'id_front': 'ID card – Front',
      'id_front_hint': 'Make sure it is readable',
      'id_back': 'ID card – Back',
      'id_back_hint': 'With all the details visible',
      'selfie': 'Verification selfie',
      'selfie_hint': 'It will be taken with your front camera.\nGallery uploads are not allowed.',
      'camera_only': 'Camera only',
      'tap_to_add': 'Tap to add',
      'add_photo': 'Add photo',
      'use_camera': 'Use camera',
      'choose_gallery': 'Choose from gallery',
      'photo_added': 'Photo added! Tap to change it',
      'selfie_taken': 'Selfie taken! Tap to retake it',
      'documents_safe':
          'Your documents are encrypted and safe. Only our verification team reviews them.',

      // KYC pending
      'account_under_review': 'Your account is being verified',
      'kyc_pending_body':
          'We already received your documents. An administrator is reviewing them and we will let you know as soon as it is approved.\n\nYou do not need to enter your details again.',
      'refresh_status': 'Refresh status',
      'still_under_review': 'Your verification is still under review',
      'status_check_failed': 'The status could not be checked. Check your connection.',

      // Service profile
      'your_star_service': 'Your flagship service',
      'service_setup_intro':
          'Choose the first service you will appear with on the platform.',
      'service_category': 'Service category',
      'search_service_hint': 'Search for your type of service...',
      'service_not_found': 'I could not find my service',
      'new_service_name': 'Name of the new service',
      'new_service_hint': 'E.g.: Home carpentry',
      'create_this_service': 'Create this service',
      'select_or_create_service': 'Select or create a service',
      'service_created': 'created successfully',
      'your_business_name': 'Your name or business name',
      'commercial_name': 'Business name',
      'commercial_name_hint': 'E.g.: John Smith / Smith Electrical',
      'pitch_title': 'Presentation line',
      'pitch_help': 'Very short: say what you do in one line.',
      'pitch_label': 'Short line',
      'pitch_hint': 'E.g.: Specialist in residential electrical installations',
      'summary_title': 'Summary of your experience',
      'summary_help':
          'Briefly describe your skills in this service. This text will appear on your profile.',
      'summary_label': 'Professional summary',
      'summary_hint':
          'Tell us what you can do, your experience, and why clients should choose you...',
      'service_setup_tip':
          '💡 Remember: you can create more services later. Focus on this one for now.',
      'start_as_ally': 'Start as an Ally!',

      // Home
      'hello_ally': 'Hi, Ally! 👋',
      'available_requests': '📋 Available requests',
      'no_requests': 'There are no requests available right now.\nCome back later!',
      'home': 'Home',
      'my_services': 'My services',
      'my_services_title': 'My Services',
      'messages': 'Messages',
      'no_messages':
          'You have no messages yet.\nYour conversations with clients will appear here.',
      'profile': 'Profile',
      'my_data': 'My details',
      'my_ratings': 'My ratings',
      'wallet': 'Wallet',
      'support': 'Support',
      'add': 'Add',
      'no_active_services':
          'You have no active services yet.\nYour first service is under review.',
      'pending_verification': 'Pending Verification',
      'verification_in_review': 'Verification under review',

      // Dashboard
      'available_services': 'Available services:',
    },
  };

  String translate(String key) =>
      _valores[locale.languageCode]?[key] ?? _valores['es']?[key] ?? key;

  String t(String key) => translate(key);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['es', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Acceso corto desde cualquier widget: `context.tr('clave')`.
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
  String tr(String key) => AppLocalizations.of(this)?.translate(key) ?? key;
}
