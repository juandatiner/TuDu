import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/user_avatar_provider.dart';
import '../services/auth_store.dart';
import '../services/user_api.dart';
import '../services/session_service.dart';
import '../l10n/app_localizations.dart';
import 'all_services_screen.dart';
import 'allies_by_service_screen.dart';
import 'publish_service_screen.dart';
import 'user_services_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;

  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _suggestionsController = PageController();
  final PageController _newServicesController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _suggestionsCurrentPage = 0;
  int _newServicesCurrentPage = 0;
  int _selectedIndex = 0;
  List<Service> _services = [];
  List<Service> _suggestedServices = [];
  List<Service> _newServices = [];
  Timer? _sessionCheckTimer;
  bool _isCheckingSession = false;
  late IO.Socket _socket;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _suggestionsController.addListener(() {
      setState(() {
        _suggestionsCurrentPage = _suggestionsController.page!.round();
      });
    });
    _newServicesController.addListener(() {
      setState(() {
        _newServicesCurrentPage = _newServicesController.page!.round();
      });
    });
    _fetchServices();
    _initializeTheme();
    WidgetsBinding.instance.addObserver(this);
    _startSessionCheck();
    _connectSocket();
    _checkUnnotifiedPhotoRequests();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del segundo plano el socket pudo haberse caído y perdido el
    // aviso de cierre. Una sola comprobación acá cubre ese hueco, sin volver
    // al sondeo permanente.
    if (state == AppLifecycleState.resumed) {
      _checkSessionStatus();
    }
  }

  void _connectSocket() {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    _socket = IO.io(
      Config.baseUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://'),
      {
        'transports': ['websocket'], 
        'autoConnect': true, 
        'forceNew': true,
        'auth': {
          'token': AuthStore.token,
          'email': widget.userEmail,
          'device_id': sessionService.deviceId,
          'device': sessionService.deviceInfo ?? '{}'
        }
      },
    );

    // El servidor avisa en el momento en que otro equipo toma la sesión.
    // Sustituye al sondeo cada 30 s: menos batería, menos datos, y el aviso
    // llega al instante en vez de con hasta medio minuto de retraso.
    _socket.off('sessionClosed');
    _socket.on('sessionClosed', (data) async {
      if (!mounted) return;
      await Provider.of<SessionService>(context, listen: false)
          .clearAllSessionData();
      if (mounted) _showSessionExpiredDialog();
    });

    _socket.off('photoRequestUpdated'); // Prevent duplicate listeners
    _socket.on('photoRequestUpdated', (data) async {
      if (data != null && data['user_email'] == widget.userEmail && mounted) {
        // Mark as notified so it won't re-appear on next app open
        if (data['id'] != null) {
          try {
            await SolicitudFotoService.marcarNotificada(data['id']);
          } catch (e) {
            debugPrint('Error marcando notificación en vivo como leída: $e');
          }
        }

        // Liberar el estado pendiente independientemente si fue aprobada o rechazada.
        if (mounted) {
          Provider.of<UserAvatarProvider>(context, listen: false)
              .setPendingPhotoRequest(false);
        }

        // If approved, push the new avatar image into the shared provider
        // so profile_screen and user_personal_data_screen update instantly.
        if (data['status'] == 'approved' &&
            data['new_avatar_image'] != null &&
            mounted) {
          final avatarProvider =
              Provider.of<UserAvatarProvider>(context, listen: false);
          await avatarProvider.applyApprovedPhoto(
            userEmail: widget.userEmail,
            newAvatarImage: data['new_avatar_image'] as String,
          );
        }

        _showPhotoRequestStatusDialog(
          status: data['status'] ?? '',
          reason: data['rejection_reason'],
        );
      }
    });
  }

  Future<void> _checkUnnotifiedPhotoRequests() async {
    try {
      final data = await SolicitudFotoService.sinNotificar(widget.userEmail);

      {
        if (data != null) {
          // Marcar como notificada inmediatamente para que no salte de nuevo
          await SolicitudFotoService.marcarNotificada(data['id']);

          _showPhotoRequestStatusDialog(
            status: data['status'],
            reason: data['rejection_reason'],
          );
        }
      }
    } catch (e) {
      debugPrint('Error comprobando notificaciones pendientes: $e');
    }
  }

  void _showPhotoRequestStatusDialog({required String status, String? reason}) {
    if (_isDialogShowing) return; // Prevent multiple dialogs
    _isDialogShowing = true;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    final isApproved = status == 'approved';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: themeProvider.cardBgColor,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isApproved ? Icons.check_circle : Icons.cancel,
                    color: isApproved ? Colors.green : Colors.red,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  isApproved 
                      ? loc.translate('photo_approved_title')
                      : loc.translate('photo_rejected_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                // Detailed reason or success msg
                Text(
                  isApproved
                      ? loc.translate('photo_approved_desc')
                      : (reason != null && reason.isNotEmpty
                          ? '${loc.translate('photo_rejected_prefix')}${loc.translate(reason) == reason ? reason : loc.translate(reason)}${loc.translate('photo_rejected_suffix')}'
                          : '${loc.translate('photo_rejected_prefix')}${loc.translate('reason_other')}${loc.translate('photo_rejected_suffix')}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: themeProvider.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproved ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loc.translate('understood'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  /// Inicializa el tema y el idioma del usuario desde el backend
  void _initializeTheme() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.initializeWithUser(widget.userEmail);

      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      languageProvider.initializeWithUser(widget.userEmail);
    });
  }

  /// El estado de la sesión ya no se sondea cada 30 segundos: el servidor
  /// empuja `sessionClosed` por socket en cuanto otro equipo la toma.
  ///
  /// Queda una sola comprobación al volver del segundo plano, por si el aviso
  /// se perdió mientras la app estaba dormida y el socket desconectado.
  void _startSessionCheck() {
    _checkSessionStatus();
  }

  /// Verifica si la sesión sigue activa
  Future<void> _checkSessionStatus() async {
    if (_isCheckingSession) return;
    _isCheckingSession = true;

    try {
      final sessionService =
          Provider.of<SessionService>(context, listen: false);
      final isActive = await sessionService.verifySessionStatus();

      if (!isActive && mounted) {
        if (sessionService.closedRemotely) {
          // Otro dispositivo tomó la sesión: ahí sí corresponde avisar.
          _showSessionExpiredDialog();
        } else {
          // Simplemente no hay sesión en este dispositivo (fila nueva, reinstalación,
          // logout previo). Volver al login sin acusar de un cierre remoto que no pasó.
          _sessionCheckTimer?.cancel();
          _navigateToLogin();
        }
      }
    } catch (e) {
      debugPrint('Error verificando sesión: $e');
    } finally {
      _isCheckingSession = false;
    }
  }

  /// Muestra diálogo de sesión expirada con el estilo de la app
  void _showSessionExpiredDialog() {
    _sessionCheckTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F2F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo Tu Du
              Column(
                children: [
                  Text(
                    'Tu',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF78BF32),
                      height: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Du',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF78BF32),
                      height: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Icono
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF78BF32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.devices,
                  size: 48,
                  color: Color(0xFF78BF32),
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                AppLocalizations.of(dialogContext)
                        ?.translate('session_closed') ??
                    'Sesión cerrada',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Mensaje
              Text(
                AppLocalizations.of(dialogContext)
                        ?.translate('session_closed_message') ??
                    'Tu sesión ha sido cerrada porque iniciaste sesión en otro dispositivo.\n\nPara usar la aplicación en este dispositivo, debes verificar tu identidad nuevamente.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black.withOpacity(0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Botón
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _navigateToLogin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    AppLocalizations.of(dialogContext)?.translate('accept') ??
                        'Aceptar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navega a la pantalla de login
  void _navigateToLogin() {
    // Limpiar el ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.clearUser();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socket.disconnect();
    _suggestionsController.dispose();
    _newServicesController.dispose();
    _searchController.dispose();
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    // Navegación para el botón de Servicios
    if (index == 2) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              UserServicesScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      // Al volver de Servicios, restablecer el índice a Inicio
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
    // Navegación para el botón de Perfil
    if (index == 3) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProfileScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      // Al volver de Perfil, restablecer el índice a Inicio
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }



  Future<void> _fetchServices() async {
    try {
      final servicesJson = await ServicioService.catalogo();
      {
        setState(() {
          _services =
              servicesJson.map((json) => Service.fromJson(json)).toList();
          _newServices = _services.length > 5
              ? _services.sublist(_services.length - 5)
              : _services;
          _suggestedServices = (List<Service>.from(_services)..shuffle())
              .take(5)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
    }
  }

  Widget _buildCarruselServicios({
    required ThemeProvider themeProvider,
    required List<Service> servicios,
    required PageController controller,
    required Color colorAcento,
    required int paginaActual,
  }) {
    if (servicios.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          AppLocalizations.of(context)?.translate('no_services') ??
              'No hay servicios disponibles',
          style: TextStyle(color: themeProvider.secondaryTextColor),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: controller,
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final service = servicios[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AlliesByServiceScreen(service: service),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: themeProvider.cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.shadowColor,
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorAcento, // Placeholder
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)
                                      ?.translate('image') ??
                                  'Imagen',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(servicios.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paginaActual == index
                    ? colorAcento
                    : themeProvider.secondaryTextColor,
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de búsqueda con autocompletado
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SearchScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeProvider.cardBgColor,
                      borderRadius: BorderRadius.circular(25.0),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.shadowColor,
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                                ?.translate('what_service_need_today') ??
                            '¿Qué servicio necesitas hoy?',
                        hintStyle: TextStyle(
                          color: themeProvider.secondaryTextColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: themeProvider.secondaryTextColor),
                        suffixIcon: Icon(Icons.mic,
                            color: themeProvider.secondaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sección Sugerencias
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)
                                      ?.translate('suggestions') ??
                                  'Sugerencias',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllServicesScreen(
                                services: _services,
                                userEmail: widget.userEmail,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.isDarkMode
                              ? themeProvider.cardBgColor
                              : const Color(0xFFE7E7E7),
                          foregroundColor: themeProvider.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppLocalizations.of(context)
                                    ?.translate('explore_more_services') ??
                                'Explorar más servicios',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Carrusel Sugerencias
                _buildCarruselServicios(
                  themeProvider: themeProvider,
                  servicios: _suggestedServices,
                  controller: _suggestionsController,
                  colorAcento: Colors.blue,
                  paginaActual: _suggestionsCurrentPage,
                ),
                const SizedBox(height: 10),
                // Sección Nuevos Servicios
                Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)?.translate('new_services') ??
                          'Nuevos Servicios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Carrusel Nuevos Servicios
                _buildCarruselServicios(
                  themeProvider: themeProvider,
                  servicios: _newServices,
                  controller: _newServicesController,
                  colorAcento: Colors.green,
                  paginaActual: _newServicesCurrentPage,
                ),
                const SizedBox(height: 10),
                // Sección "¿No encuentras lo que buscas?"
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? themeProvider.cardBgColor
                        : const Color(0xFFE7E7E7),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.shadowColor,
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppLocalizations.of(context)
                                  ?.translate('cant_find_what_looking_for') ??
                              '¿No encuentras lo que buscas?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context)
                                ?.translate('publish_request_experts') ??
                            'Publica tu solicitud y deja que los expertos vengan a ti. No pierdas tiempo buscando, ¡ellos te encontrarán!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublishServiceScreen(
                                userEmail: widget.userEmail,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF78BF32,
                          ), // Verde #78BF32
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 100,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          AppLocalizations.of(context)
                                  ?.translate('publish_btn') ??
                              'Publicar',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              hoverColor: ThemeProvider.primaryColor.withOpacity(0.1),
            ),
            // `removeBottom` saca el hueco que el sistema reserva bajo la barra
            // para el indicador de inicio. Sin esto quedaba una franja vacía
            // grande debajo de los íconos.
            child: MediaQuery(
              // No `removeBottom` a secas: quitaba todo el margen y las
              // etiquetas quedaban pegadas al borde. Se deja una franja
              // pequeña, suficiente para que respire sin la banda enorme que
              // reserva el sistema.
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).padding.copyWith(bottom: 6),
              ),
              child: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: AppLocalizations.of(context)?.translate('home') ??
                        'Inicio'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.message),
                    label:
                        AppLocalizations.of(context)?.translate('messages') ??
                            'Mensajes'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.work),
                    label:
                        AppLocalizations.of(context)?.translate('services') ??
                            'Servicios'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.person),
                    label: AppLocalizations.of(context)?.translate('profile') ??
                        'Perfil'),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: ThemeProvider.primaryColor,
              unselectedItemColor: Colors.grey,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: themeProvider.cardBgColor,
              elevation: 10,
              ),
            ),
          );
        },
      ),
    );
  }
}
