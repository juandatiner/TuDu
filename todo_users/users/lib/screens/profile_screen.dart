import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;

  const ProfileScreen({super.key, required this.userEmail});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Usuario';
  String _avatarColor = '#78BF32'; // Color por defecto
  String? _avatarImage; // URL de imagen si existe
  bool _isLoading = true;

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
          _avatarImage = data['avatar_image'];
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

  Future<void> _updateAvatarColor(String color) async {
    try {
      await http.put(
        Uri.parse('${Config.baseUrl}/users/profile/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userEmail,
          'avatar_color': color,
        }),
      );
      setState(() {
        _avatarColor = color;
      });
    } catch (e) {
      print('Error updating avatar color: $e');
    }
  }

  void _showAvatarColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Color del Avatar'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              '#78BF32',
              '#FF5733',
              '#3357FF',
              '#FF33F5',
              '#33FFF5',
              '#FFC300',
              '#900C3F',
              '#1ABC9C',
              '#8E44AD',
              '#2C3E50',
            ].map((color) {
              return GestureDetector(
                onTap: () {
                  _updateAvatarColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _parseColor(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _avatarColor == color
                          ? Colors.black
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
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
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Nombre del usuario
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Avatar
                            GestureDetector(
                              onTap: _showAvatarColorPicker,
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
                                        child: Image.network(
                                          _avatarImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.white,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
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
                            icon: Icons.person_outline,
                            label: 'Mis Datos',
                            onTap: () {
                              // Sin funcionalidad por ahora
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.credit_card,
                            label: 'Tarjetas',
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
                        icon: Icons.palette_outlined,
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
