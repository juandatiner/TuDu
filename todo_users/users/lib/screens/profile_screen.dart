import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'home_screen.dart';
import 'user_services_screen.dart';
import 'user_personal_data_screen.dart';

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
  bool _isLoading = true;
  int _selectedIndex = 3; // Perfil está seleccionado

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/profile/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userName = data['name'] ?? 'Usuario';
          _avatarColor = data['avatar_color'] ?? '#78BF32';
          _avatarIcon = data['avatar_icon'] ?? 'person';
          _avatarImage = data['avatar_image'];
          _phoneNumber = data['phone'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'account_circle':
        return Icons.account_circle;
      case 'face':
        return Icons.face;
      case 'supervisor_account':
        return Icons.supervisor_account;
      case 'business':
        return Icons.business;
      case 'school':
        return Icons.school;
      case 'child_care':
        return Icons.child_care;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.person;
    }
  }

  Widget _getIconWidget() {
    return Icon(
      _getIconData(_avatarIcon),
      size: 40,
      color: Colors.white,
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      // Inicio
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              HomeScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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
                                color: _parseColor(_avatarColor),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: _avatarImage != null
                                  ? ClipOval(
                                      child: _avatarImage!
                                              .startsWith('data:image')
                                          ? Image.memory(
                                              base64Decode(
                                                  _avatarImage!.split(',')[1]),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return _getIconWidget();
                                              },
                                            )
                                          : Image.network(
                                              _avatarImage!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return _getIconWidget();
                                              },
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
                            icon: Icons.support_agent,
                            label: 'Soporte',
                            onTap: () {
                              // Sin funcionalidad por ahora
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.badge_outlined,
                            label: 'Mis Datos',
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
                            icon: Icons.credit_card,
                            label: 'Mis Tarjetas',
                            onTap: () {
                              // Sin funcionalidad por ahora
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Sección Ajustes
                      const Text(
                        'Ajustes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        icon: Icons.location_on_outlined,
                        title: 'Mis direcciones',
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),

                      _buildSettingsItem(
                        icon: Icons.light_mode,
                        title: 'Apariencia',
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.language,
                        title: 'Idioma',
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),
                      const SizedBox(height: 30),
                      // Sección Otros
                      const Text(
                        'Otros',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        icon: Icons.delete_outline,
                        title: 'Eliminar Cuenta',
                        isDestructive: true,
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.description_outlined,
                        title: 'Términos y Condiciones',
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'Cerrar Sesión',
                        isDestructive: true,
                        onTap: () {
                          // Sin funcionalidad por ahora
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Servicios'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                  color: isDestructive ? Colors.red : Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
