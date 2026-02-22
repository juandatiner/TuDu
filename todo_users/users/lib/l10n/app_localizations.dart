import 'package:flutter/material.dart';

/// Clase para manejar las traducciones de la aplicación
/// Soporta español e inglés
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// Obtener las localizaciones actuales del contexto
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Delegado para cargar las localizaciones
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Mapa de traducciones
  static const Map<String, Map<String, String>> _localizedValues = {
    'es': {
      // Navegación y generales
      'app_name': 'To Do',
      'home': 'Inicio',
      'profile': 'Perfil',
      'messages': 'Mensajes',
      'services': 'Servicios',
      'settings': 'Ajustes',
      'other': 'Otros',
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',
      'cancel': 'Cancelar',
      'accept': 'Aceptar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'search': 'Buscar',
      'close': 'Cerrar',
      'back': 'Volver',
      'continue_button': 'Continuar',
      'retry': 'Reintentar',

      // Autenticación
      'login': 'Iniciar Sesión',
      'logout': 'Cerrar Sesión',
      'logout_confirmation': '¿Estás seguro de que quieres cerrar sesión?',
      'register': 'Registrarse',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'confirm_password': 'Confirmar contraseña',
      'forgot_password': '¿Olvidaste tu contraseña?',
      'no_account': '¿No tienes cuenta?',
      'have_account': '¿Ya tienes cuenta?',
      'phone_number': 'Número de teléfono',
      'verification_code': 'Código de verificación',
      'verify': 'Verificar',
      'verification_success': 'Verificación exitosa',
      'verification_failed': 'Verificación fallida',

      // Perfil
      'my_data': 'Mis Datos',
      'my_addresses': 'Mis direcciones',
      'my_cards': 'Mis Tarjetas',
      'support': 'Soporte',
      'appearance': 'Apariencia',
      'language': 'Idioma',
      'data_protection': 'Protección de Datos',
      'terms_and_conditions': 'Términos y Condiciones',
      'user': 'Usuario',

      // Apariencia
      'theme': 'Tema',
      'light_theme': 'Tema Claro',
      'dark_theme': 'Tema Oscuro',
      'system_theme': 'Tema del Sistema',
      'select_theme': 'Seleccionar tema',

      // Idioma
      'select_language': 'Seleccionar idioma',
      'spanish': 'Español',
      'english': 'Inglés',
      'spanish_colombia': 'Español (Colombia)',
      'english_us': 'English (US)',
      'language_changed': 'Idioma cambiado correctamente',
      'language_info_message':
          'El idioma seleccionado se guardará automáticamente y se aplicará cada vez que abras la aplicación.',

      // Servicios
      'all_services': 'Todos los Servicios',
      'my_services': 'Mis Servicios',
      'publish_service': 'Publicar Servicio',
      'service_detail': 'Detalle del Servicio',
      'allies_by_service': 'Aliados por Servicio',
      'no_services': 'No hay servicios disponibles',
      'no_services_published': 'No has publicado ningún servicio',

      // Búsqueda
      'search_services': 'Buscar servicios...',
      'search_results': 'Resultados de búsqueda',
      'no_results': 'No se encontraron resultados',

      // Direcciones
      'add_address': 'Agregar dirección',
      'edit_address': 'Editar dirección',
      'delete_address': 'Eliminar dirección',
      'address_name': 'Nombre de la dirección',
      'address_hint': 'Ej: Casa, Trabajo, etc.',
      'department': 'Departamento',
      'city': 'Ciudad',
      'address': 'Dirección',
      'address_details': 'Detalles adicionales',
      'select_department': 'Selecciona un departamento',
      'select_city': 'Selecciona una ciudad',
      'address_saved': 'Dirección guardada',
      'address_deleted': 'Dirección eliminada',

      // Onboarding
      'welcome': 'Bienvenido',
      'welcome_message': 'Tu plataforma de servicios de confianza',
      'get_started': 'Comenzar',
      'skip': 'Omitir',
      'next': 'Siguiente',

      // Errores y validaciones
      'error_connection': 'Error de conexión',
      'error_server': 'Error del servidor',
      'error_unknown': 'Error desconocido',
      'error_invalid_email': 'Correo electrónico inválido',
      'error_invalid_phone': 'Número de teléfono inválido',
      'error_required_field': 'Este campo es requerido',
      'error_password_match': 'Las contraseñas no coinciden',
      'error_short_password': 'La contraseña debe tener al menos 6 caracteres',

      // Mensajes de éxito
      'profile_updated': 'Perfil actualizado correctamente',
      'changes_saved': 'Cambios guardados',

      // Días de la semana
      'monday': 'Lunes',
      'tuesday': 'Martes',
      'wednesday': 'Miércoles',
      'thursday': 'Jueves',
      'friday': 'Viernes',
      'saturday': 'Sábado',
      'sunday': 'Domingo',

      // Meses
      'january': 'Enero',
      'february': 'Febrero',
      'march': 'Marzo',
      'april': 'Abril',
      'may': 'Mayo',
      'june': 'Junio',
      'july': 'Julio',
      'august': 'Agosto',
      'september': 'Septiembre',
      'october': 'Octubre',
      'november': 'Noviembre',
      'december': 'Diciembre',
    },
    'en': {
      // Navigation and general
      'app_name': 'To Do',
      'home': 'Home',
      'profile': 'Profile',
      'messages': 'Messages',
      'services': 'Services',
      'settings': 'Settings',
      'other': 'Other',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'accept': 'Accept',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'close': 'Close',
      'back': 'Back',
      'continue_button': 'Continue',
      'retry': 'Retry',

      // Authentication
      'login': 'Log In',
      'logout': 'Log Out',
      'logout_confirmation': 'Are you sure you want to log out?',
      'register': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm password',
      'forgot_password': 'Forgot your password?',
      'no_account': "Don't have an account?",
      'have_account': 'Already have an account?',
      'phone_number': 'Phone number',
      'verification_code': 'Verification code',
      'verify': 'Verify',
      'verification_success': 'Verification successful',
      'verification_failed': 'Verification failed',

      // Profile
      'my_data': 'My Data',
      'my_addresses': 'My Addresses',
      'my_cards': 'My Cards',
      'support': 'Support',
      'appearance': 'Appearance',
      'language': 'Language',
      'data_protection': 'Data Protection',
      'terms_and_conditions': 'Terms and Conditions',
      'user': 'User',

      // Appearance
      'theme': 'Theme',
      'light_theme': 'Light Theme',
      'dark_theme': 'Dark Theme',
      'system_theme': 'System Theme',
      'select_theme': 'Select theme',

      // Language
      'select_language': 'Select language',
      'spanish': 'Spanish',
      'english': 'English',
      'spanish_colombia': 'Spanish (Colombia)',
      'english_us': 'English (US)',
      'language_changed': 'Language changed successfully',
      'language_info_message':
          'The selected language will be saved automatically and applied every time you open the application.',

      // Services
      'all_services': 'All Services',
      'my_services': 'My Services',
      'publish_service': 'Publish Service',
      'service_detail': 'Service Detail',
      'allies_by_service': 'Allies by Service',
      'no_services': 'No services available',
      'no_services_published': 'You haven\'t published any service',

      // Search
      'search_services': 'Search services...',
      'search_results': 'Search results',
      'no_results': 'No results found',

      // Addresses
      'add_address': 'Add address',
      'edit_address': 'Edit address',
      'delete_address': 'Delete address',
      'address_name': 'Address name',
      'address_hint': 'E.g.: Home, Work, etc.',
      'department': 'Department',
      'city': 'City',
      'address': 'Address',
      'address_details': 'Additional details',
      'select_department': 'Select a department',
      'select_city': 'Select a city',
      'address_saved': 'Address saved',
      'address_deleted': 'Address deleted',

      // Onboarding
      'welcome': 'Welcome',
      'welcome_message': 'Your trusted services platform',
      'get_started': 'Get Started',
      'skip': 'Skip',
      'next': 'Next',

      // Errors and validations
      'error_connection': 'Connection error',
      'error_server': 'Server error',
      'error_unknown': 'Unknown error',
      'error_invalid_email': 'Invalid email',
      'error_invalid_phone': 'Invalid phone number',
      'error_required_field': 'This field is required',
      'error_password_match': 'Passwords do not match',
      'error_short_password': 'Password must be at least 6 characters',

      // Success messages
      'profile_updated': 'Profile updated successfully',
      'changes_saved': 'Changes saved',

      // Days of the week
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',

      // Months
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',
    },
  };

  /// Obtener una traducción por clave
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['es']?[key] ??
        key;
  }

  /// Método abreviado para traducir
  String t(String key) => translate(key);
}

/// Delegado para cargar las localizaciones
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extensión para facilitar el acceso a las traducciones
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
  String tr(String key) => AppLocalizations.of(this)?.translate(key) ?? key;
}
