import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Imagen',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Recortar Imagen',
          ),
        ],
      );
      if (croppedFile != null) {
        try {
          var request = http.MultipartRequest(
              'PUT', Uri.parse('${Config.baseUrl}/users/profile/avatar'));
          request.fields['email'] = widget.userEmail;
          request.files.add(await http.MultipartFile.fromPath(
              'avatar_image', croppedFile.path));
          var response = await request.send();
          var responseBody = await response.stream.bytesToString();
          if (response.statusCode == 200) {
            var data = json.decode(responseBody);
            setState(() {
              _avatarImage = data['avatar_image'];
            });
          } else {
            print('Error uploading image: ${response.statusCode}');
          }
        } catch (e) {
          print('Error: $e');
        }
      }
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
                            child: GestureDetector(
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
                                        child: _avatarImage!
                                                .startsWith('data:image')
                                            ? Image.memory(
                                                base64Decode(_avatarImage!
                                                    .split(',')[1]),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: Colors.white,
                                                  );
                                                },
                                              )
                                            : Image.network(
                                                _avatarImage!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
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
                        icon: Icons.image,
                        title: 'Editar Imagen',
                        onTap: () {
                          _pickAndUploadImage();
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
