import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/session_service.dart';
import '../l10n/app_localizations.dart';
import 'user_services_screen.dart';
import 'user_personal_data_screen.dart';
import 'user_addresses_screen.dart';
import 'user_cards_screen.dart';
import 'terms_and_conditions_screen.dart';
import 'data_protection_screen.dart';
import 'login_screen.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;

  const ProfileScreen({super.key, required this.userEmail});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Usuario';
  String _avatarColor = '#78BF32'; // Color por defecto
  String _avatarIcon = 'person'; // Icono por defecto
  String? _avatarImage; // URL de imagen si existe
  String _phoneNumber = '';
  int _selectedIndex = 3; // Perfil está seleccionado

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _loadUserProfile();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'profile_${widget.userEmail}_';

      if (prefs.containsKey('${keyPrefix}name')) {
        setState(() {
          _userName = prefs.getString('${keyPrefix}name') ?? 'Usuario';
          _avatarColor = prefs.getString('${keyPrefix}color') ?? '#78BF32';
          _avatarIcon = prefs.getString('${keyPrefix}icon') ?? 'person';
          _avatarImage = prefs.getString('${keyPrefix}image');
        });
      }
    } catch (e) {
      print('Error loading cached profile: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/profile/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userName =
              '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim() != ''
                  ? '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim()
                  : 'Usuario';
          _avatarColor = data['avatar_color'] ?? '#78BF32';
          _avatarIcon = data['avatar_icon'] ?? 'person';
          _avatarImage = data['avatar_image'];
          _phoneNumber = data['phone'] ?? '';

          _saveCachedProfile();
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _saveCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'profile_${widget.userEmail}_';

      await prefs.setString('${keyPrefix}name', _userName);
      await prefs.setString('${keyPrefix}color', _avatarColor);
      await prefs.setString('${keyPrefix}icon', _avatarIcon);
      if (_avatarImage != null) {
        await prefs.setString('${keyPrefix}image', _avatarImage!);
      } else {
        await prefs.remove('${keyPrefix}image');
      }
    } catch (e) {
      print('Error saving cached profile: $e');
    }
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'mood_happy':
        return Icons.mood;
      case 'man':
        return Icons.man;
      case 'woman':
        return Icons.woman;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'music_note':
        return Icons.music_note;
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
        return Icons.store;
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      default:
        return Icons.mood;
    }
  }

  Widget _getIconWidget() {
    return Icon(
      _getIconData(_avatarIcon),
      size: 40,
      color: Colors.white,
    );
  }

  void _showLogoutDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: themeProvider.cardBgColor,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  loc.translate('logout'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Content
                Text(
                  loc.translate('logout_confirmation'),
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.isDarkMode
                                ? themeProvider.cardBgColor
                                : Colors.white,
                            foregroundColor: const Color(0xFF78BF32),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFF78BF32),
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            loc.translate('cancel'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Logout Button
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            loc.translate('logout'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout() async {
    // Cerrar sesión en el servidor y limpiar datos locales
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.logout();

    // Limpiar el usuario del ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.clearUser();

    // Limpiar el usuario del LanguageProvider
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.clearUser();

    // Navegar a la pantalla de login limpiando todo el historial de navegación
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      // Inicio: Volver a la pantalla principal sin apilar múltiples instancias
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (index == 1) {
      // Mensajes - por implementar
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 2) {
      // Servicios
      Navigator.pushReplacement(
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
    } else if (index == 3) {
      // Perfil - ya estamos aquí
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Sección del perfil: Nombre y Avatar
                Row(
                  children: [
                    // Nombre del usuario - a la izquierda
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ),
                    ),
                    // Avatar - más a la derecha
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              (_avatarImage != null && _avatarImage!.isNotEmpty)
                                  ? Colors.transparent
                                  : _parseColor(_avatarColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? themeProvider.cardBgColor
                                : Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.shadowColor,
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: (_avatarImage != null &&
                                _avatarImage!.isNotEmpty)
                            ? ClipOval(
                                child: _avatarImage!.startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(
                                            _avatarImage!.split(',')[1]),
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                        frameBuilder: (context, child, frame,
                                            wasSynchronouslyLoaded) {
                                          if (wasSynchronouslyLoaded ||
                                              frame != null) return child;
                                          return const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2));
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _getIconWidget();
                                        },
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: _avatarImage!,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            _getIconWidget(),
                                        placeholder: (context, url) =>
                                            const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                      ),
                              )
                            : _getIconWidget(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Tres botones horizontales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      context: context,
                      icon: Icons.support_agent,
                      label: loc.translate('support'),
                      onTap: () {
                        // Sin funcionalidad por ahora
                      },
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.badge_outlined,
                      label: loc.translate('my_data'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MyDataScreen(userEmail: widget.userEmail),
                          ),
                        );
                        // Si hubo cambios, recargar el perfil
                        if (result == true) {
                          _loadUserProfile();
                        }
                      },
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.credit_card,
                      label: loc.translate('my_cards'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MyCardsScreen(userEmail: widget.userEmail),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Sección Ajustes
                Text(
                  loc.translate('settings'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.location_on_outlined,
                  title: loc.translate('my_addresses'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserAddressesScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                ),

                _buildSettingsItem(
                  context: context,
                  icon: Icons.light_mode,
                  title: loc.translate('appearance'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppearanceScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.language,
                  title: loc.translate('language'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguageScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                // Sección Otros
                Text(
                  loc.translate('other'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.security_outlined,
                  title: loc.translate('data_protection'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DataProtectionScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.description_outlined,
                  title: loc.translate('terms_and_conditions'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsAndConditionsScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.logout,
                  title: loc.translate('logout'),
                  isDestructive: true,
                  onTap: () {
                    _showLogoutDialog();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: loc.translate('home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.message),
                label: loc.translate('messages'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.work),
                label: loc.translate('services'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: loc.translate('profile'),
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: themeProvider.cardBgColor,
            elevation: 10,
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF78BF32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: themeProvider.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? Colors.red : const Color(0xFF78BF32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : themeProvider.textColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: themeProvider.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}
