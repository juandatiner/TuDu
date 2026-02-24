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
      'appearance_subtitle':
          'Personaliza la apariencia de la aplicación según tus preferencias.',
      'light_theme_desc': 'Fondo claro con textos oscuros',
      'dark_theme_desc': 'Fondo gris oscuro con textos claros',
      'theme_info_message':
          'El tema seleccionado se guardará automáticamente y se aplicará cada vez que abras la aplicación.',

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
      'no_addresses': 'No tienes direcciones guardadas',
      'add_first_address': 'Agrega tu primera dirección',
      'address_icon': 'Icono',
      'type_via': 'Tipo de vía',
      'select_type_via': 'Selecciona el tipo de vía',
      'number_principal': 'Número principal',
      'number_secondary': 'Número secundario',
      'number_final': 'Número final',
      'additional_info': 'Información Adicional',
      'field_required': 'Campo obligatorio',
      'must_contain_digit': 'Debe contener al menos un dígito',
      'error_adding_address': 'Error al agregar dirección',
      'error_updating_address': 'Error al actualizar dirección',
      'no_changes': 'Aún no has hecho cambios',
      'confirm_delete': '¿Estás seguro de eliminar esta dirección?',
      'location_label': 'Ubicación',
      'icon_home': 'Casa',
      'icon_apartment': 'Apartamento',
      'icon_company': 'Empresa',
      'icon_school': 'Colegio',
      'icon_store': 'Tienda',
      'icon_church': 'Iglesia',
      'icon_hospital': 'Hospital',
      'icon_restaurant': 'Restaurante',
      'icon_hotel': 'Hotel',
      'icon_gym': 'Gimnasio',
      'icon_park': 'Parque',
      'icon_farm': 'Finca',
      'via_street': 'Calle',
      'via_avenue': 'Avenida',
      'via_diagonal': 'Diagonal',
      'via_transversal': 'Transversal',
      'via_circular': 'Circular',
      'via_highway': 'Autopista',
      'via_road': 'Carretera',
      'via_path': 'Camino',
      'via_race': 'Carrera',
      'location': 'Ubicación',
      'address_name_label': 'Nombre',
      'address_name_hint': 'Casa, Empresa...',
      'department_label': 'Departamento',
      'city_label': 'Ciudad',
      'type_via_label': 'Tipo de vía',
      'number_principal_label': 'Número principal',
      'number_secondary_label': 'Número secundario',
      'number_final_label': 'Número final',
      'additional_info_label': 'Información Adicional',
      'additional_info_hint': 'ej: Edificio X, Apto 101',
      'icon_label': 'Icono',
      'cancel_btn': 'Cancelar',
      'add_btn': 'Agregar',
      'save_btn': 'Guardar',
      'close_btn': 'Cerrar',
      'delete_address_title': 'Eliminar Dirección',
      'delete_address_confirm': '¿Estás seguro de eliminar esta dirección?',
      'delete_btn': 'Eliminar',
      'select_department_first': 'Selecciona primero un departamento',
      'no_cities_available': 'No hay ciudades disponibles',

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

      // Términos y Condiciones
      'terms_welcome': 'Bienvenido a nuestra aplicación',
      'terms_intro_title': '1. Introducción',
      'terms_intro_text':
          'Al utilizar nuestra aplicación, usted acepta estos términos y condiciones de uso. Por favor, léalos cuidadosamente antes de acceder o usar la aplicación.',
      'terms_usage_title': '2. Uso de la aplicación',
      'terms_usage_text':
          'Nuestra aplicación es una plataforma que conecta usuarios con servicios y aliados. Usted se compromete a usar la aplicación solo para fines legales y de acuerdo con estas políticas.',
      'terms_responsibilities_title': '3. Responsabilidades',
      'terms_responsibilities_text':
          'Usted es responsable de mantener la confidencialidad de su cuenta y contraseña. Debe notificarnos inmediatamente si detecta cualquier uso no autorizado de su cuenta.',
      'terms_intellectual_property_title': '4. Propiedad intelectual',
      'terms_intellectual_property_text':
          'Todos los derechos reservados. La aplicación y su contenido son propiedad exclusiva de nuestra empresa y están protegidos por las leyes de propiedad intelectual.',
      'terms_modifications_title': '5. Modificaciones',
      'terms_modifications_text':
          'Nos reservamos el derecho de modificar estos términos y condiciones en cualquier momento. Las modificaciones entrarán en vigor inmediatamente al publicarlas en la aplicación.',
      'terms_contact_title': '6. Contacto',
      'terms_contact_text':
          'Si tienes alguna pregunta sobre estos términos y condiciones, por favor contáctanos a través de la sección de soporte de la aplicación.',
      'terms_last_update': 'Fecha de última actualización: Febrero 2026',

      // Protección de Datos
      'data_protection_policy': 'Política de Protección de Datos',
      'data_collection_title': '1. Recopilación de información',
      'data_collection_text':
          'Recopilamos información que usted nos proporciona directamente, como su nombre, correo electrónico, número de teléfono y otra información necesaria para brindarle nuestros servicios.',
      'data_usage_title': '2. Uso de la información',
      'data_usage_text':
          'Utilizamos su información para proporcionar, mantener y mejorar nuestros servicios, procesar transacciones, enviar comunicaciones relacionadas con el servicio y proteger contra fraudes.',
      'data_sharing_title': '3. Compartir información',
      'data_sharing_text':
          'No vendemos ni alquilamos su información personal a terceros. Solo compartimos su información con proveedores de servicios que nos ayudan a operar nuestra aplicación y cumplir con la ley.',
      'data_security_title': '4. Seguridad de datos',
      'data_security_text':
          'Implementamos medidas de seguridad técnicas y organizativas para proteger su información personal contra acceso no autorizado, alteración, divulgación o destrucción.',
      'data_rights_title': '5. Sus derechos',
      'data_rights_text':
          'Usted tiene derecho a acceder, corregir, eliminar y portar su información personal. También tiene derecho a oponerse al procesamiento de sus datos en ciertas circunstancias.',
      'data_cookies_title': '6. Cookies y tecnologías similares',
      'data_cookies_text':
          'Utilizamos cookies y tecnologías similares para mejorar su experiencia, analizar el uso de nuestra aplicación y personalizar el contenido que se le muestra.',
      'data_contact_title': '7. Contacto',
      'data_contact_text':
          'Si tiene preguntas sobre esta política de protección de datos, puede contactarnos a través de la sección de soporte de la aplicación.',
      'data_last_update': 'Fecha de última actualización: Febrero 2026',

      // Pantalla Mis Datos
      'change_avatar': 'Cambiar Avatar',
      'upload_photo': 'Subir Foto',
      'set_avatar': 'Colocar Avatar',
      'change_photo': 'Cambiar Foto',
      'delete_photo': 'Eliminar Foto',
      'customize_avatar': 'Personalizar Avatar',
      'select_icon': 'Selecciona un icono:',
      'select_color': 'Selecciona un color:',
      'confirm': 'Confirmar',
      'image_too_heavy': 'La imagen es demasiado pesada. Máximo 5 MB.',
      'image_too_large':
          'La imagen es demasiado grande. Máximo 4000x4000 píxeles.',
      'data_updated_success': 'Datos actualizados exitosamente',
      'error_saving_data': 'Error al guardar los datos',
      'name': 'Nombre',
      'please_enter_name': 'Por favor ingresa tu nombre',
      'name_max_length': 'El nombre no puede exceder 20 caracteres',
      'last_name': 'Apellido',
      'please_enter_last_name': 'Por favor ingresa tu apellido',
      'last_name_max_length': 'El apellido no puede exceder 20 caracteres',
      'phone': 'Teléfono',
      'phone_too_short': 'El número de teléfono es muy corto',
      'gender': 'Género',
      'please_select_gender': 'Por favor selecciona tu género',
      'select': 'Seleccionar',
      'birth_date': 'Fecha de Nacimiento',
      'select_your_gender': 'Selecciona tu género',
      'this_info_required': 'Esta información es obligatoria',
      'must_be_18': 'Debes ser mayor de 18 años',
      'please_select_birth_date': 'Por favor selecciona tu fecha de nacimiento',
      'must_be_18_to_use': 'Debes ser mayor de 18 años para usar la aplicación',
      'save_changes': 'Guardar Cambios',
      'woman': 'Mujer',
      'man': 'Hombre',
      'non_binary': 'No binario',
      'none_of_above': 'Ninguna de las opciones',

      // Pantalla Mis Tarjetas
      'add_card': 'Agregar Tarjeta',
      'edit_card': 'Editar Tarjeta',
      'delete_card': 'Eliminar Tarjeta',
      'card_number': 'Número de Tarjeta',
      'card_holder': 'Titular de la Tarjeta',
      'expiry_date': 'Vence',
      'cvv': 'CVV',
      'save_card': 'Guardar Tarjeta',
      'card_deleted': 'Tarjeta eliminada',
      'card_saved': 'Tarjeta guardada',
      'error_saving_card': 'Error al guardar la tarjeta',
      'no_cards': 'No tienes tarjetas guardadas',
      'add_first_card': 'Agrega tu primera tarjeta',
      'card_number_hint': '1234 5678 9010 1112',
      'card_holder_hint': 'Nombre Completo',
      'expiry_date_hint': 'MM/AA',
      'cvv_hint': '123',
      'card_number_required': 'Por favor ingresa el número de tarjeta',
      'card_number_invalid': 'Número de tarjeta inválido',
      'card_holder_required': 'Por favor ingresa el titular de la tarjeta',
      'expiry_date_required': 'Por favor ingresa la fecha de expiración',
      'expiry_date_invalid': 'Fecha de expiración inválida',
      'cvv_required': 'Por favor ingresa el CVV',
      'cvv_invalid': 'CVV inválido',
      'favorite_card': 'Tarjeta Favorita',
      'favorite_card_description':
          'Esta tarjeta se usará para pagos predeterminados',
      'set_favorite_card': 'Establecer como favorita',
      'favorite_card_title': 'Tarjeta Favorita',
      'other_cards': 'Otras Tarjetas',
      'already_favorite': 'Ya es favorita',
      'first_card_auto_favorite': 'Automático',
      'first_card_favorite_description':
          'La primera tarjeta será la favorita automáticamente',
      'document': 'Documento',
      'document_required': 'Por favor ingresa el documento',
      'card_holder_label': 'Titular',
      'expires_label': 'Vence',
      'card_already_exists': 'Ya existe una tarjeta con este número',
      'max_cards_reached':
          'Has alcanzado el límite máximo de 7 tarjetas. Para agregar una nueva, primero elimina una existente.',

      // Pantalla Mis Servicios
      'what_service_looking_for': '¿Qué servicio buscas?',
      'services_count': 'servicios',
      'of': 'de',
      'status_label': 'Estado:',
      'all': 'Todos',
      'sort_by': 'Ordenar por:',
      'newest': 'Más reciente',
      'oldest': 'Más antiguo',
      'no_services_assigned': 'No tienes servicios asignados',
      'search_or_publish': 'Busca o publica que necesitas',
      'search_services_btn': 'Buscar Servicios',
      'no_results_for': 'No se encontraron resultados para',
      'no_services_with_filters': 'No hay servicios con estos filtros',
      'clear_filters': 'Limpiar filtros',
      'waiting_status': 'EN ESPERA',
      'in_process_status': 'EN PROCESO',
      'finished_status': 'TERMINADO',
      'cancelled_status': 'CANCELADO',
      'delayed_status': 'RETRASADO',
      'completed_status': 'FINALIZADO',
      'year_singular': 'año',
      'year_plural': 'años',
      'month_singular': 'mes',
      'month_plural': 'meses',
      'week_singular': 'semana',
      'week_plural': 'semanas',
      'day_singular': 'día',
      'day_plural': 'días',
      'hour_singular': 'hora',
      'hour_plural': 'horas',

      // Pantalla Detalles del Servicio
      'service_details': 'Detalles del Servicio',
      'start': 'Inicio',
      'finish': 'Finalización',
      'pending_assignment': 'Pendiente por asignar',
      'in_process': 'En proceso',
      'finished': 'Terminado',
      'cancelled': 'Cancelado',
      'delayed': 'Retrasado',
      'completed': 'Finalizado',
      'in_development': 'En desarrollo',
      'in_delay': 'En retraso',
      'ally_in_charge': 'Aliado a cargo',
      'description': 'Descripción',
      'estimated_time': 'Tiempo estimado',
      'budget': 'Presupuesto',
      'worker_info': 'Información para el trabajador',
      'no_additional_info': 'Sin información adicional',
      'publication_date': 'Fecha de publicación',
      'stop_searching_ally': 'Dejar de buscar Aliado',
      'stop_searching_confirmation':
          '¿Estás seguro de que deseas dejar de buscar un Aliado para este servicio?',
      'service_deleted_success': 'Servicio eliminado exitosamente',
      'error_deleting_service': 'Error al eliminar el servicio',

      // Pantalla de Inicio (Home)
      'what_service_need_today': '¿Qué servicio necesitas hoy?',
      'suggestions': 'Sugerencias',
      'explore_more_services': 'Explorar más servicios',
      'image': 'Imagen',
      'home_service': 'Servicio de hogar',
      'new_services': 'Nuevos Servicios',
      'cant_find_what_looking_for': '¿No encuentras lo que buscas?',
      'publish_request_experts':
          'Publica tu solicitud y deja que los expertos vengan a ti. No pierdas tiempo buscando, ¡ellos te encontrarán!',
      'publish_btn': 'Publicar',

      // Diálogo de sesión expirada
      'session_closed': 'Sesión cerrada',
      'session_closed_message':
          'Tu sesión ha sido cerrada porque iniciaste sesión en otro dispositivo.\n\nPara usar la aplicación en este dispositivo, debes verificar tu identidad nuevamente.',

      // Pantalla Todos los Servicios
      'services_of': 'Servicios de...',
      'no_results_for_query': "No encontramos resultados para",
      'no_results_found': 'No se encontraron resultados',
      'try_different_search': 'Intenta buscando de otra manera',

      // Pantalla Publicar Servicio
      'publish_your_need': 'Publica lo que necesitas',
      'describe_need_phrase': '¿Cómo describirías tu necesidad en una frase?',
      'describe_need_placeholder':
          'Describe en al menos 3 palabras tu necesidad',
      'min_3_words': 'Mínimo 3 palabras para mayor claridad',
      'how_long_service':
          '¿Cuánto tiempo crees que tomará completar este servicio?',
      'max_time_exceeded': '⚠️ Tiempo máximo excedido (1 año)',
      'summary': 'Resumen',
      'max_time_exceeded_summary': 'Tiempo máximo excedido',
      'how_much_pay': '¿Cuánto estás dispuesto a pagar por este servicio?',
      'min_budget': 'El mínimo es \$5.000 pesos',
      'max_budget': 'El máximo es \$100.000.000 pesos',
      'enter_budget': 'Ingresa el presupuesto',
      'min_budget_error': 'El presupuesto mínimo es de \$5.000 pesos',
      'max_budget_error': 'El presupuesto máximo es de \$100.000.000 de pesos',
      'describe_better': 'Describe mejor lo que necesitas',
      'describe_better_placeholder':
          'Describe con detalle lo que necesitas (mínimo 20 palabras)',
      'min_20_words': 'Describe con más detalle (mínimo 20 palabras)',
      'worker_know_before':
          '¿Hay algo que el trabajador deba saber antes de postularse?',
      'additional_info_worker': 'Información adicional para el trabajador',
      'all_fields_required': 'Todos los campos son obligatorios',
      'title_min_3_words': 'El título debe tener al menos 3 palabras',
      'description_min_20_words':
          'La descripción debe tener al menos 20 palabras',
      'service_published_success': 'Servicio publicado exitosamente!',
      'error_publishing_service': 'Error al publicar el servicio',
      'connection_error': 'Error de conexión',

      // Unidades de tiempo
      'hours': 'Horas',
      'days': 'Días',
      'weeks': 'Semanas',
      'months': 'Meses',
      'years': 'Años',
      'hour': 'Hora',
      'day': 'Día',
      'week': 'Semana',
      'month': 'Mes',
      'year': 'Año',
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
      'appearance_subtitle':
          'Customize the appearance of the application according to your preferences.',
      'light_theme_desc': 'Light background with dark text',
      'dark_theme_desc': 'Dark gray background with light text',
      'theme_info_message':
          'The selected theme will be saved automatically and applied every time you open the application.',

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
      'no_addresses': 'You have no saved addresses',
      'add_first_address': 'Add your first address',
      'address_icon': 'Icon',
      'type_via': 'Road type',
      'select_type_via': 'Select the road type',
      'number_principal': 'Principal number',
      'number_secondary': 'Secondary number',
      'number_final': 'Final number',
      'additional_info': 'Additional Information',
      'field_required': 'Required field',
      'must_contain_digit': 'Must contain at least one digit',
      'error_adding_address': 'Error adding address',
      'error_updating_address': 'Error updating address',
      'no_changes': 'You haven\'t made any changes yet',
      'confirm_delete': 'Are you sure you want to delete this address?',
      'location_label': 'Location',
      'icon_home': 'Home',
      'icon_apartment': 'Apartment',
      'icon_company': 'Company',
      'icon_school': 'School',
      'icon_store': 'Store',
      'icon_church': 'Church',
      'icon_hospital': 'Hospital',
      'icon_restaurant': 'Restaurant',
      'icon_hotel': 'Hotel',
      'icon_gym': 'Gym',
      'icon_park': 'Park',
      'icon_farm': 'Farm',
      'via_street': 'Street',
      'via_avenue': 'Avenue',
      'via_diagonal': 'Diagonal',
      'via_transversal': 'Transversal',
      'via_circular': 'Circular',
      'via_highway': 'Highway',
      'via_road': 'Road',
      'via_path': 'Path',
      'via_race': 'Race',
      'location': 'Location',
      'address_name_label': 'Name',
      'address_name_hint': 'Home, Company...',
      'department_label': 'Department',
      'city_label': 'City',
      'type_via_label': 'Road type',
      'number_principal_label': 'Principal number',
      'number_secondary_label': 'Secondary number',
      'number_final_label': 'Final number',
      'additional_info_label': 'Additional Information',
      'additional_info_hint': 'e.g.: Building X, Apt 101',
      'icon_label': 'Icon',
      'cancel_btn': 'Cancel',
      'add_btn': 'Add',
      'save_btn': 'Save',
      'close_btn': 'Close',
      'delete_address_title': 'Delete Address',
      'delete_address_confirm': 'Are you sure you want to delete this address?',
      'delete_btn': 'Delete',
      'select_department_first': 'Select a department first',
      'no_cities_available': 'No cities available',

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

      // Terms and Conditions
      'terms_welcome': 'Welcome to our application',
      'terms_intro_title': '1. Introduction',
      'terms_intro_text':
          'By using our application, you accept these terms and conditions of use. Please read them carefully before accessing or using the application.',
      'terms_usage_title': '2. Use of the application',
      'terms_usage_text':
          'Our application is a platform that connects users with services and allies. You agree to use the application only for legal purposes and in accordance with these policies.',
      'terms_responsibilities_title': '3. Responsibilities',
      'terms_responsibilities_text':
          'You are responsible for maintaining the confidentiality of your account and password. You must notify us immediately if you detect any unauthorized use of your account.',
      'terms_intellectual_property_title': '4. Intellectual property',
      'terms_intellectual_property_text':
          'All rights reserved. The application and its content are exclusive property of our company and are protected by intellectual property laws.',
      'terms_modifications_title': '5. Modifications',
      'terms_modifications_text':
          'We reserve the right to modify these terms and conditions at any time. Modifications will take effect immediately upon publication in the application.',
      'terms_contact_title': '6. Contact',
      'terms_contact_text':
          'If you have any questions about these terms and conditions, please contact us through the support section of the application.',
      'terms_last_update': 'Last update: February 2026',

      // Data Protection
      'data_protection_policy': 'Data Protection Policy',
      'data_collection_title': '1. Information collection',
      'data_collection_text':
          'We collect information that you provide directly to us, such as your name, email, phone number, and other information necessary to provide our services.',
      'data_usage_title': '2. Use of information',
      'data_usage_text':
          'We use your information to provide, maintain, and improve our services, process transactions, send service-related communications, and protect against fraud.',
      'data_sharing_title': '3. Sharing information',
      'data_sharing_text':
          'We do not sell or rent your personal information to third parties. We only share your information with service providers who help us operate our application and comply with the law.',
      'data_security_title': '4. Data security',
      'data_security_text':
          'We implement technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
      'data_rights_title': '5. Your rights',
      'data_rights_text':
          'You have the right to access, correct, delete, and port your personal information. You also have the right to object to the processing of your data in certain circumstances.',
      'data_cookies_title': '6. Cookies and similar technologies',
      'data_cookies_text':
          'We use cookies and similar technologies to improve your experience, analyze the use of our application, and personalize the content shown to you.',
      'data_contact_title': '7. Contact',
      'data_contact_text':
          'If you have questions about this data protection policy, you can contact us through the support section of the application.',
      'data_last_update': 'Last update: February 2026',

      // My Data Screen
      'change_avatar': 'Change Avatar',
      'upload_photo': 'Upload Photo',
      'set_avatar': 'Set Avatar',
      'change_photo': 'Change Photo',
      'delete_photo': 'Delete Photo',
      'customize_avatar': 'Customize Avatar',
      'select_icon': 'Select an icon:',
      'select_color': 'Select a color:',
      'confirm': 'Confirm',
      'image_too_heavy': 'The image is too heavy. Maximum 5 MB.',
      'image_too_large': 'The image is too large. Maximum 4000x4000 pixels.',
      'data_updated_success': 'Data updated successfully',
      'error_saving_data': 'Error saving data',
      'name': 'Name',
      'please_enter_name': 'Please enter your name',
      'name_max_length': 'Name cannot exceed 20 characters',
      'last_name': 'Last Name',
      'please_enter_last_name': 'Please enter your last name',
      'last_name_max_length': 'Last name cannot exceed 20 characters',
      'phone': 'Phone',
      'phone_too_short': 'Phone number is too short',
      'gender': 'Gender',
      'please_select_gender': 'Please select your gender',
      'select': 'Select',
      'birth_date': 'Birth Date',
      'select_your_gender': 'Select your gender',
      'this_info_required': 'This information is required',
      'must_be_18': 'You must be 18 or older',
      'please_select_birth_date': 'Please select your birth date',
      'must_be_18_to_use': 'You must be 18 or older to use the application',
      'save_changes': 'Save Changes',
      'woman': 'Woman',
      'man': 'Man',
      'non_binary': 'Non-binary',
      'none_of_above': 'None of the above',

      // My Cards Screen
      'add_card': 'Add Card',
      'edit_card': 'Edit Card',
      'delete_card': 'Delete Card',
      'card_number': 'Card Number',
      'card_holder': 'Card Holder',
      'expiry_date': 'Expires',
      'cvv': 'CVV',
      'save_card': 'Save Card',
      'card_deleted': 'Card deleted',
      'card_saved': 'Card saved',
      'error_saving_card': 'Error saving card',
      'no_cards': 'You have no saved cards',
      'add_first_card': 'Add your first card',
      'card_number_hint': '1234 5678 9010 1112',
      'card_holder_hint': 'Full Name',
      'expiry_date_hint': 'MM/YY',
      'cvv_hint': '123',
      'card_number_required': 'Please enter card number',
      'card_number_invalid': 'Invalid card number',
      'card_holder_required': 'Please enter card holder',
      'expiry_date_required': 'Please enter expiry date',
      'expiry_date_invalid': 'Invalid expiry date',
      'cvv_required': 'Please enter CVV',
      'cvv_invalid': 'Invalid CVV',
      'favorite_card': 'Favorite Card',
      'favorite_card_description':
          'This card will be used for default payments',
      'set_favorite_card': 'Set as favorite',
      'favorite_card_title': 'Favorite Card',
      'other_cards': 'Other Cards',
      'already_favorite': 'Already favorite',
      'first_card_auto_favorite': 'Automatic',
      'first_card_favorite_description':
          'The first card will be the favorite automatically',
      'document': 'Document',
      'document_required': 'Please enter the document',
      'card_holder_label': 'Card Holder',
      'expires_label': 'Expires',
      'card_already_exists': 'A card with this number already exists',
      'max_cards_reached':
          'You have reached the maximum limit of 7 cards. To add a new one, please delete an existing card first.',

      // My Services Screen
      'what_service_looking_for': 'Search service...',
      'services_count': 'services',
      'of': 'of',
      'status_label': 'Status:',
      'all': 'All',
      'sort_by': 'Sort by:',
      'newest': 'Newest',
      'oldest': 'Oldest',
      'no_services_assigned': 'You have no assigned services',
      'search_or_publish': 'Search or publish what you need',
      'search_services_btn': 'Search Services',
      'no_results_for': 'No results found for',
      'no_services_with_filters': 'No services with these filters',
      'clear_filters': 'Clear filters',
      'waiting_status': 'WAITING',
      'in_process_status': 'IN PROCESS',
      'finished_status': 'FINISHED',
      'cancelled_status': 'CANCELLED',
      'delayed_status': 'DELAYED',
      'completed_status': 'COMPLETED',
      'year_singular': 'year',
      'year_plural': 'years',
      'month_singular': 'month',
      'month_plural': 'months',
      'week_singular': 'week',
      'week_plural': 'weeks',
      'day_singular': 'day',
      'day_plural': 'days',
      'hour_singular': 'hour',
      'hour_plural': 'hours',

      // Service Details Screen
      'service_details': 'Service Details',
      'start': 'Start',
      'finish': 'Finish',
      'pending_assignment': 'Pending assignment',
      'in_process': 'In process',
      'finished': 'Finished',
      'cancelled': 'Cancelled',
      'delayed': 'Delayed',
      'completed': 'Completed',
      'in_development': 'In development',
      'in_delay': 'In delay',
      'ally_in_charge': 'Ally in charge',
      'description': 'Description',
      'estimated_time': 'Estimated time',
      'budget': 'Budget',
      'worker_info': 'Information for worker',
      'no_additional_info': 'No additional information',
      'publication_date': 'Publication date',
      'stop_searching_ally': 'Stop searching for Ally',
      'stop_searching_confirmation':
          'Are you sure you want to stop searching for an Ally for this service?',
      'service_deleted_success': 'Service deleted successfully',
      'error_deleting_service': 'Error deleting service',

      // Home Screen
      'what_service_need_today': 'What service do you need today?',
      'suggestions': 'Suggestions',
      'explore_more_services': 'Explore more services',
      'image': 'Image',
      'home_service': 'Home service',
      'new_services': 'New Services',
      'cant_find_what_looking_for': "Can't find what you're looking for?",
      'publish_request_experts':
          'Publish your request and let the experts come to you. Stop wasting time searching, they will find you!',
      'publish_btn': 'Publish',

      // Session Expired Dialog
      'session_closed': 'Session closed',
      'session_closed_message':
          'Your session has been closed because you logged in on another device.\n\nTo use the application on this device, you must verify your identity again.',

      // All Services Screen
      'services_of': 'Services of...',
      'no_results_for_query': "We couldn't find results for",
      'no_results_found': 'No results found',
      'try_different_search': 'Try searching differently',

      // Publish Service Screen
      'publish_your_need': 'Publish what you need',
      'describe_need_phrase': 'How would you describe your need in one phrase?',
      'describe_need_placeholder': 'Describe your need in at least 3 words',
      'min_3_words': 'Minimum 3 words for clarity',
      'how_long_service': 'How long do you think this service will take?',
      'max_time_exceeded': '⚠️ Maximum time exceeded (1 year)',
      'summary': 'Summary',
      'max_time_exceeded_summary': 'Maximum time exceeded',
      'how_much_pay': 'How much are you willing to pay for this service?',
      'min_budget': 'Minimum is \$5,000 pesos',
      'max_budget': 'Maximum is \$100,000,000 pesos',
      'enter_budget': 'Enter the budget',
      'min_budget_error': 'Minimum budget is \$5,000 pesos',
      'max_budget_error': 'Maximum budget is \$100,000,000 pesos',
      'describe_better': 'Describe better what you need',
      'describe_better_placeholder':
          'Describe in detail what you need (minimum 20 words)',
      'min_20_words': 'Describe in more detail (minimum 20 words)',
      'worker_know_before':
          'Is there anything the worker should know before applying?',
      'additional_info_worker': 'Additional information for the worker',
      'all_fields_required': 'All fields are required',
      'title_min_3_words': 'Title must have at least 3 words',
      'description_min_20_words': 'Description must have at least 20 words',
      'service_published_success': 'Service published successfully!',
      'error_publishing_service': 'Error publishing service',
      'connection_error': 'Connection error',

      // Time units
      'hours': 'Hours',
      'days': 'Days',
      'weeks': 'Weeks',
      'months': 'Months',
      'years': 'Years',
      'hour': 'Hour',
      'day': 'Day',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
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
