import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:convert';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../config.dart';

class MyDataScreen extends StatefulWidget {
  final String userEmail;

  const MyDataScreen({super.key, required this.userEmail});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  String _completePhone = ''; // Teléfono completo con código de país
  String _countryCode = ''; // Código de país (ej: +57)
  String _phoneNumber = ''; // Número sin código de país

  bool _isLoading = true;
  bool _isSaving = false;
  String _avatarColor = '#78BF32';
  XFile? _selectedImage;
  String _selectedIcon = 'person'; // Icono por defecto
  bool _usePhoto = false; // true si usa foto, false si usa icono
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.userEmail;
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _avatarImage; // URL de la imagen de perfil existente

  Future<void> _loadUserData() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/profile/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fullName = data['name'] ?? '';
        final nameParts = fullName.split(' ');

        setState(() {
          _nameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
          _lastNameController.text =
              nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          _avatarColor = data['avatar_color'] ?? '#78BF32';
          _selectedIcon = data['avatar_icon'] ?? 'person';
          _avatarImage = data['avatar_image'];
          // Si hay una imagen de perfil, marcar que se usa foto
          if (data['avatar_image'] != null) {
            _usePhoto = true;
          }
          _isLoading = false;
        });

        // Cargar teléfono si existe
        _loadUserPhone();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPhone() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/profile/phone/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final phone = data['phone'] ?? '';
        setState(() {
          _completePhone = phone;
        });
      }
    } catch (e) {
      print('Error loading phone: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Guardar datos básicos
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/users/profile/data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userEmail,
          'nombre': _nameController.text.trim(),
          'apellido': _lastNameController.text.trim(),
          'phone': _completePhone,
        }),
      );

      // Subir imagen de perfil o actualizar avatar
      final avatarResponse = await http.put(
        Uri.parse('${Config.baseUrl}/users/profile/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userEmail,
          'avatar_image': _usePhoto ? _avatarImage : null,
          'avatar_color': _avatarColor,
          'avatar_icon': _selectedIcon,
        }),
      );
      if (avatarResponse.statusCode != 200) {
        print('Error updating avatar: ${avatarResponse.statusCode}');
      }

      setState(() {
        _isSaving = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos actualizados exitosamente'),
            backgroundColor: Color(0xFF78BF32),
          ),
        );
        Navigator.pop(
            context, true); // Retorna true para indicar que hubo cambios
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['error'] ?? 'Error al guardar los datos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_usePhoto)
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF78BF32)),
                  title: const Text('Cambiar Avatar'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAvatarOptionsDialog();
                  },
                ),
              if (!_usePhoto)
                ListTile(
                  leading: const Icon(Icons.photo, color: Color(0xFF78BF32)),
                  title: const Text('Subir Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage();
                  },
                ),
              if (_usePhoto)
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF78BF32)),
                  title: const Text('Colocar Avatar'),
                  onTap: () async {
                    Navigator.pop(context);
                    final randomIcon = [
                      'mood_happy',
                      'man',
                      'woman',
                      'sports_esports',
                      'music_note',
                      'restaurant',
                      'store',
                      'home',
                      'work',
                      'school'
                    ][DateTime.now().millisecondsSinceEpoch % 10];
                    setState(() {
                      _usePhoto = false;
                      _selectedImage = null;
                      _avatarImage = null;
                      _selectedIcon = randomIcon;
                    });
                    // Actualizar backend con el nuevo avatar
                    await _updateAvatar(_avatarColor, randomIcon);
                  },
                ),
              if (_usePhoto)
                ListTile(
                  leading: const Icon(Icons.photo, color: Color(0xFF78BF32)),
                  title: const Text('Cambiar Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage();
                  },
                ),
              if (_usePhoto)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar Foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final randomIcon = [
                      'mood_happy',
                      'man',
                      'woman',
                      'sports_esports',
                      'music_note',
                      'restaurant',
                      'store',
                      'home',
                      'work',
                      'school'
                    ][DateTime.now().millisecondsSinceEpoch % 10];
                    setState(() {
                      _usePhoto = false;
                      _selectedImage = null;
                      _avatarImage = null;
                      _selectedIcon = randomIcon;
                    });
                    // Actualizar backend con el nuevo avatar
                    await _updateAvatar(_avatarColor, randomIcon);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAvatarOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cambiar Avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selecciona un icono:'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    'mood_happy',
                    'man',
                    'woman',
                    'sports_esports',
                    'music_note',
                    'restaurant',
                    'store',
                    'home',
                    'work',
                    'school',
                  ].map((iconName) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconName;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _selectedIcon == iconName
                              ? Colors.blue
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedIcon == iconName
                                ? Colors.blue
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getIconData(iconName),
                          size: 24,
                          color: _selectedIcon == iconName
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Selecciona un color:'),
                const SizedBox(height: 16),
                Wrap(
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
                        setState(() {
                          _avatarColor = color;
                        });
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
              ],
            ),
          ),
        );
      },
    );
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
      _getIconData(_selectedIcon),
      size: 60,
      color: Colors.white,
    );
  }

  Future<void> _updateAvatar(String color, String icon) async {
    try {
      await http.put(
        Uri.parse('${Config.baseUrl}/users/profile/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userEmail,
          'avatar_color': color,
          'avatar_icon': icon,
          'avatar_image': null,
        }),
      );
    } catch (e) {
      print('Error updating avatar: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
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
        // Convertir imagen a base64
        final bytes = await File(croppedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() {
          _selectedImage = XFile(croppedFile.path);
          _usePhoto = true;
          _avatarImage = 'data:image/jpeg;base64,$base64Image';
        });
      }
    }
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Datos',
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _parseColor(_avatarColor),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 3,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _selectedImage != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(_selectedImage!.path),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _avatarImage != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          base64Decode(
                                              _avatarImage!.split(',')[1]),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return _getIconWidget();
                                          },
                                        ),
                                      )
                                    : _getIconWidget(),
                          ),
                          GestureDetector(
                            onTap: _showAvatarOptions,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF78BF32),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Campo Nombre
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _nameController,
                          maxLength: 50,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            labelStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.person_outline,
                                color: Color(0xFF78BF32)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            if (value.trim().length > 50) {
                              return 'El nombre no puede exceder 50 caracteres';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Apellido
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _lastNameController,
                          maxLength: 50,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                            labelStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.person_outline,
                                color: Color(0xFF78BF32)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa tu apellido';
                            }
                            if (value.trim().length > 50) {
                              return 'El apellido no puede exceder 50 caracteres';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Email (solo lectura)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: TextStyle(color: Colors.grey),
                            prefixIcon:
                                Icon(Icons.email_outlined, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Teléfono con selector de país
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IntlPhoneField(
                          initialValue: _completePhone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            labelStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                            prefixIcon: Icon(Icons.phone_outlined,
                                color: Color(0xFF78BF32)),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.phone,
                          dropdownIcon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF78BF32)),
                          dropdownIconPosition: IconPosition.trailing,
                          showCountryFlag: true,
                          showDropdownIcon: true,
                          initialCountryCode: 'CO', // Colombia por defecto
                          onChanged: (phone) {
                            setState(() {
                              _completePhone = phone.completeNumber;
                              _countryCode = phone.countryCode;
                              _phoneNumber = phone.number;
                            });
                          },
                          onCountryChanged: (country) {
                            setState(() {
                              _countryCode = '+${country.dialCode}';
                            });
                          },
                          validator: (phone) {
                            if (phone != null && phone.number.isNotEmpty) {
                              // Validación básica del número
                              if (phone.number.length < 6) {
                                return 'El número de teléfono es muy corto';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78BF32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Guardar Cambios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
