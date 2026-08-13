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
      'error_nuestro': 'Algo falló de nuestro lado. Vuelve a intentarlo en un momento.',
      'error_sin_red': 'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.',
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
      'kyc_disclaimer':
          'Los datos deben ser reales y coincidir con tu identidad. Toma la foto directo a tu cédula física — no sirven capturas de pantalla, fotos de otra foto ni copias. Documentos falsos, alterados o ilegibles serán rechazados.',
      'id_front': 'Cédula – Parte frontal',
      'id_front_hint': 'Foto de tu cédula física, legible y sin reflejos',
      'id_back': 'Cédula – Parte trasera',
      'id_back_hint': 'Foto de tu cédula física, con todos los datos visibles',
      'selfie': 'Selfie de verificación',
      'selfie_hint': 'Se tomará con tu cámara frontal.\nNo se puede adjuntar de galería.',
      'camera_only': 'Solo cámara',
      'camera': 'Cámara',
      'gallery': 'Galería',
      'tap_to_add': 'Toca para agregar',
      'photo_added': '¡Foto agregada! Toca para cambiarla',
      'selfie_taken': '¡Selfie tomada! Toca para repetirla',
      'documents_safe':
          'Tus documentos están cifrados y seguros. Solo nuestro equipo de verificación los revisa.',
      'camera_error':
          'No se pudo acceder a la cámara. Revisa los permisos de la app o intenta de nuevo.',
      'support_soon_title': '¿Tienes un problema?',
      'support_soon_body':
          'Muy pronto podrás escribirle directo a nuestro equipo de soporte desde aquí.',

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
      'search_category_hint': 'Busca tu categoría (ej: Carpintería)...',
      'category_not_found': 'No encontré mi categoría',
      'new_category_name': 'Nombre de la nueva categoría',
      'new_category_hint': 'Ej: Carpintería',
      'suggest_category': 'Proponer esta categoría',
      'category_suggested': 'Categoría enviada a revisión',
      'pending_review_badge': 'Pendiente de revisión',
      'service_name_label': 'Servicio dentro de esta categoría',
      'service_not_found': 'Cuéntanos qué servicio ofreces',
      'new_service_name': 'Nombre del nuevo servicio',
      'new_service_hint': 'Ej: Instalación de puertas de madera',
      'new_service_description': 'Descripción corta',
      'new_service_description_hint': 'Ej: Instalación y ajuste de puertas de madera a medida',
      'portfolio_title': 'Pruebas de tu trabajo',
      'portfolio_disclaimer':
          'Sube al menos una foto de un trabajo que hayas hecho antes, para que la gente vea la calidad de tu servicio. Debe ser tuya, real y corresponder a este servicio — nuestro equipo revisa cada solicitud a mano. No se aceptan fotos que no correspondan, imágenes generadas con IA ni contenido inapropiado: si detectamos eso, tu servicio no será aprobado.',
      'service_name_too_short': 'Escribe al menos 3 caracteres',
      'service_description_required': 'Escribe al menos 5 palabras',
      'commercial_name_too_short': 'Escribe al menos 3 caracteres',
      'pitch_too_short': 'Escribe al menos 3 palabras',
      'summary_too_short': 'Escribe al menos 15 palabras',
      'portfolio_required': 'Sube al menos una foto de un trabajo real que hayas hecho',
      'portfolio_already_sent': 'Ya enviaste tus fotos de prueba para este servicio',
      'photo_duplicated': 'Esa foto ya la agregaste',
      'select_or_create_service': 'Selecciona una categoría o propone una nueva',
      'service_created': 'creado exitosamente',
      'service_suggested': 'Servicio guardado, queda en revisión',
      'review_approved': 'Aprobado',
      'review_rejected': 'Rechazado',
      'review_pending': 'En revisión',
      'review_reason_title': 'Motivo',
      'review_waiting_category': 'Esperando la aprobación de la categoría',
      'review_category_rejected': 'La categoría que propusiste no fue aprobada',
      'fix_service_title': 'Corregir servicio',
      'fix_and_resend': 'Corregir y reenviar',
      'fix_this_field': 'Corregir esto',
      'fix_photos_replace_help':
          'Sube fotos nuevas: reemplazan a las anteriores, que fueron las que no pasaron la revisión.',
      'fix_photos_optional_help':
          'Solo si quieres agregar pruebas nuevas. Las que ya enviaste se conservan.',
      'kyc_rejected_title': 'Tu identidad no fue aprobada',
      // Perfil comercial del aliado (paso entre KYC y primer servicio)
      'ally_profile_title': 'Tu perfil de aliado',
      'ally_profile_intro':
          'Así te verán los usuarios. Se pide una sola vez: vale para todos los servicios que ofrezcas.',
      'add_profile_photo': 'Agregar foto de perfil',
      'change_photo': 'Cambiar foto',
      'photo_required': 'Agrega una foto de perfil',
      'photo_needs_review': 'Tu foto pasa por revisión antes de mostrarse.',
      'photo_too_heavy': 'Esa foto pesa demasiado. Elige una más liviana.',
      'save_changes': 'Guardar cambios',
      'data_saved': 'Datos actualizados',
      'photo_under_review': 'Tu foto está en revisión',
      'photo_approved': 'Tu foto de perfil fue aprobada',
      'photo_rejected': 'Tu foto de perfil no fue aprobada',
      'continue_to_service': 'Continuar',
      'verified_badge': 'Verificado',
      'account_under_review_short': 'Tu cuenta está en revisión',
      'review_banner_title': 'Estamos verificando tu cuenta',
      'review_banner_body':
          'Es el último paso. Mientras tanto puedes mirar las solicitudes, pero aún no tomarlas ni aparecer en las búsquedas. Te avisamos apenas quede lista.',
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
          'Este es tu primer servicio. Más adelante vas a poder agregar otros desde tu perfil.',
      'start_as_ally': '¡Comenzar como Aliado!',
      'create_first_service': 'Crear primer servicio',
      'create_service': 'Crear servicio',
      'service_sent_title': '¡Tu servicio está en camino!',
      'service_sent_body':
          'Nuestro equipo lo va a revisar para asegurarse de que todo esté en orden. Te avisamos apenas quede público y la gente pueda contratarte.',
      'understood': 'Entendido',

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
      'error_nuestro': 'Something went wrong on our side. Please try again in a moment.',
      'error_sin_red': 'We could not connect. Check your connection and try again.',
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
      'kyc_disclaimer':
          'Your data must be real and match your identity. Photograph your physical ID card directly — screenshots, photos of another photo, or copies are not accepted. Fake, altered, or unreadable documents will be rejected.',
      'id_front': 'ID card – Front',
      'id_front_hint': 'Photo of your physical ID card, readable and glare-free',
      'id_back': 'ID card – Back',
      'id_back_hint': 'Photo of your physical ID card, with all details visible',
      'selfie': 'Verification selfie',
      'selfie_hint': 'It will be taken with your front camera.\nGallery uploads are not allowed.',
      'camera_only': 'Camera only',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'tap_to_add': 'Tap to add',
      'photo_added': 'Photo added! Tap to change it',
      'selfie_taken': 'Selfie taken! Tap to retake it',
      'documents_safe':
          'Your documents are encrypted and safe. Only our verification team reviews them.',
      'camera_error':
          'Could not access the camera. Check the app permissions or try again.',
      'support_soon_title': 'Having a problem?',
      'support_soon_body':
          'Soon you will be able to message our support team directly from here.',

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
      'search_category_hint': 'Search your category (e.g. Carpentry)...',
      'category_not_found': 'I could not find my category',
      'new_category_name': 'New category name',
      'new_category_hint': 'E.g.: Carpentry',
      'suggest_category': 'Suggest this category',
      'category_suggested': 'Category sent for review',
      'pending_review_badge': 'Pending review',
      'service_name_label': 'Service within this category',
      'service_not_found': 'Tell us what service you offer',
      'new_service_name': 'Name of the new service',
      'new_service_hint': 'E.g.: Wooden door installation',
      'new_service_description': 'Short description',
      'new_service_description_hint': 'E.g.: Installation and fitting of custom wooden doors',
      'portfolio_title': 'Proof of your work',
      'portfolio_disclaimer':
          'Upload at least one photo of work you have done before, so people can see the quality of your service. It must be your own, real, and match this service — our team reviews every submission by hand. Photos that do not match, AI-generated images, and inappropriate content are not accepted: if we detect that, your service will not be approved.',
      'service_name_too_short': 'Write at least 3 characters',
      'service_description_required': 'Write at least 5 words',
      'commercial_name_too_short': 'Write at least 3 characters',
      'pitch_too_short': 'Write at least 3 words',
      'summary_too_short': 'Write at least 15 words',
      'portfolio_required': 'Upload at least one photo of real work you have done',
      'portfolio_already_sent': 'You already sent your proof photos for this service',
      'photo_duplicated': 'You already added that photo',
      'select_or_create_service': 'Pick a category or suggest a new one',
      'service_created': 'created successfully',
      'service_suggested': 'Service saved, pending review',
      'review_approved': 'Approved',
      'review_rejected': 'Rejected',
      'review_pending': 'Under review',
      'review_reason_title': 'Reason',
      'review_waiting_category': 'Waiting for the category to be approved',
      'review_category_rejected': 'The category you suggested was not approved',
      'fix_service_title': 'Fix service',
      'fix_and_resend': 'Fix and resend',
      'fix_this_field': 'Fix this',
      'fix_photos_replace_help':
          'Upload new photos: they replace the previous ones, which were the ones that did not pass review.',
      'fix_photos_optional_help':
          'Only if you want to add new proof. The ones you already sent are kept.',
      'kyc_rejected_title': 'Your identity was not approved',
      // Ally commercial profile (step between KYC and first service)
      'ally_profile_title': 'Your ally profile',
      'ally_profile_intro':
          'This is how users will see you. Asked only once: it applies to every service you offer.',
      'add_profile_photo': 'Add profile photo',
      'change_photo': 'Change photo',
      'photo_required': 'Add a profile photo',
      'photo_needs_review': 'Your photo is reviewed before it is shown.',
      'photo_too_heavy': 'That photo is too heavy. Choose a lighter one.',
      'save_changes': 'Save changes',
      'data_saved': 'Details updated',
      'photo_under_review': 'Your photo is under review',
      'photo_approved': 'Your profile photo was approved',
      'photo_rejected': 'Your profile photo was not approved',
      'continue_to_service': 'Continue',
      'verified_badge': 'Verified',
      'account_under_review_short': 'Your account is under review',
      'review_banner_title': 'We are verifying your account',
      'review_banner_body':
          'It is the last step. Meanwhile you can browse requests, but not take them or show up in searches yet. We will let you know as soon as it is ready.',
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
          'This is your first service. You will be able to add more later from your profile.',
      'start_as_ally': 'Start as an Ally!',
      'create_first_service': 'Create first service',
      'create_service': 'Create service',
      'service_sent_title': 'Your service is on its way!',
      'service_sent_body':
          'Our team will review it to make sure everything is in order. We will let you know as soon as it goes public and people can hire you.',
      'understood': 'Got it',

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
