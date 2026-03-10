import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final _phoneController = TextEditingController();

  String _completePhone = ''; // Teléfono completo con código de país
  String _countryCode = ''; // Código de país (ej: +57)
  String _countryName = ''; // Nombre del país (ej: Angola)
  String _phoneNumber = ''; // Número sin código de país
  String _initialCountryCode = 'CO'; // Código de país inicial para el selector
  Key _phoneFieldKey = UniqueKey(); // Key para forzar reconstrucción del campo

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasPendingPhotoRequest = false;
  String _avatarColor = '#78BF32';
  XFile? _selectedImage;
  String _selectedIcon = 'person'; // Icono por defecto
  bool _usePhoto = false; // true si usa foto, false si usa icono
  final ImagePicker _picker = ImagePicker();

  // Género
  String? _selectedGender;
  String? _originalGender;

  List<Map<String, String>> _getGenderOptions(AppLocalizations loc) {
    return [
      {'value': 'mujer', 'label': loc.t('woman')},
      {'value': 'hombre', 'label': loc.t('man')},
      {'value': 'no_binario', 'label': loc.t('non_binary')},
      {'value': 'ninguna', 'label': loc.t('none_of_above')},
    ];
  }

  // Fecha de nacimiento
  DateTime? _birthDate;
  DateTime? _originalBirthDate;
  String? _birthDateError;

  // Datos originales del usuario para comparar cambios
  String? _originalName;
  String? _originalLastName;
  String? _originalPhone;
  String? _originalAvatarColor;
  String? _originalAvatarIcon;
  String? _originalAvatarImage;
  bool? _originalUsePhoto;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.userEmail;

    // Agregar listeners a los controladores de texto para detectar cambios
    _nameController.addListener(() => setState(() {}));
    _lastNameController.addListener(() => setState(() {}));

    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar datos cada vez que la pantalla se muestra (incluso al regresar de otras pantallas)
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _avatarImage; // URL de la imagen de perfil existente

  /// Obtiene el código ISO del país desde el código de marcación usando la API
  Future<String> _getCountryCodeFromDialCode(String dialCode) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/countries/by-dial/$dialCode'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['iso_code'] ?? 'CO';
      }
    } catch (e) {
      print('Error obteniendo país: $e');
    }
    return 'CO';
  }

  Future<void> _loadUserData() async {
    try {
      // Verificar si hay solicitud pendiente de cambio de foto
      final pendingRequestResponse = await http.get(
        Uri.parse(
            '${Config.baseUrl}/api/user/photo-change-request/pending?user_email=${widget.userEmail}'),
      );

      if (pendingRequestResponse.statusCode == 200) {
        final pendingData = json.decode(pendingRequestResponse.body);
        setState(() {
          _hasPendingPhotoRequest = pendingData['data'] != null;
        });
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/profile/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _nameController.text = data['nombre'] ?? '';
          _lastNameController.text = data['apellido'] ?? '';
          _avatarColor = data['avatar_color'] ?? '#78BF32';
          _selectedIcon = data['avatar_icon'] ?? 'person';
          _avatarImage = data['avatar_image'];
          _completePhone = data['phone'] ?? '';

          // Cargar datos separados si están disponibles
          final countryCodeFromDb = data['country_code'];
          final countryNameFromDb = data['country_name'];
          final phoneNumberFromDb = data['phone_number'];

          if (countryCodeFromDb != null &&
              countryCodeFromDb.isNotEmpty &&
              phoneNumberFromDb != null &&
              phoneNumberFromDb.isNotEmpty) {
            // Usar los datos separados de la BD
            _countryCode = countryCodeFromDb;
            _countryName = countryNameFromDb ?? '';
            _phoneNumber = phoneNumberFromDb;
            _phoneController.text = _phoneNumber;
            // Obtener el código ISO del país desde el código de marcación
            _initialCountryCode = 'CO'; // Temporal, se actualizará después
            _phoneFieldKey = UniqueKey();
          } else if (_completePhone.isNotEmpty) {
            // Fallback: el widget IntlPhoneField manejará el parseo
            _phoneController.text = '';
            _initialCountryCode = 'CO';
          } else {
            _phoneController.text = '';
            _initialCountryCode = 'CO'; // Colombia por defecto
          }

          // Si hay una imagen de perfil, marcar que se usa foto
          if (data['avatar_image'] != null) {
            _usePhoto = true;
          } else {
            _usePhoto = false;
          }

          // Guardar datos originales
          _originalName = data['nombre'] ?? '';
          _originalLastName = data['apellido'] ?? '';
          _originalAvatarColor = data['avatar_color'] ?? '#78BF32';
          _originalAvatarIcon = data['avatar_icon'] ?? 'person';
          _originalAvatarImage = data['avatar_image'];
          _originalUsePhoto = data['avatar_image'] != null;
          _originalPhone = data['phone'] ?? '';
          _selectedGender = data['genero'];
          _originalGender = data['genero'];

          // Cargar fecha de nacimiento
          if (data['fecha_nacimiento'] != null &&
              data['fecha_nacimiento'].toString().isNotEmpty) {
            try {
              _birthDate = DateTime.parse(data['fecha_nacimiento']);
              _originalBirthDate = _birthDate;
            } catch (e) {
              print('Error parsing birth date: $e');
            }
          }

          _isLoading = false;
        });

        // Si hay código de país, obtener el código ISO desde la API
        if (_countryCode.isNotEmpty) {
          final isoCode = await _getCountryCodeFromDialCode(_countryCode);
          setState(() {
            _initialCountryCode = isoCode;
            _phoneFieldKey = UniqueKey();
          });
        }
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
          _originalPhone = phone;
        });
      }
    } catch (e) {
      print('Error loading phone: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    final loc = AppLocalizations.of(context)!;

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
          'country_code': _countryCode,
          'country_name': _countryName,
          'phone_number': _phoneNumber,
          'genero': _selectedGender,
          'fecha_nacimiento': _birthDate?.toIso8601String(),
        }),
      );

      // Si no hay una solicitud pendiente y se cambió el avatar, actualizar directamente
      if (!_hasPendingPhotoRequest) {
        final avatarResponse = await http.put(
          Uri.parse('${Config.baseUrl}/users/profile/avatar'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': widget.userEmail,
            'avatar_image': _usePhoto ? _avatarImage : null,
            // Solo enviar color y icono si no se usa foto
            if (!_usePhoto) ...{
              'avatar_color': _avatarColor,
              'avatar_icon': _selectedIcon,
            },
          }),
        );
        if (avatarResponse.statusCode != 200) {
          print('Error updating avatar: ${avatarResponse.statusCode}');
        }
      }

      setState(() {
        _isSaving = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('data_updated_success')),
            backgroundColor: const Color(0xFF78BF32),
          ),
        );
        Navigator.pop(
            context, true); // Retorna true para indicar que hubo cambios
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['error'] ?? loc.t('error_saving_data')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('error_connection')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAvatarOptions() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.cardBgColor,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasPendingPhotoRequest)
                ListTile(
                  leading: const Icon(Icons.pending, color: Colors.orange),
                  title: Text(
                    'Para poder cambiar de nuevo, debes esperar el cambio que solicitaste',
                    style: TextStyle(color: themeProvider.textColor),
                  ),
                ),
              if (!_usePhoto)
                ListTile(
                  leading: Icon(Icons.person,
                      color: _hasPendingPhotoRequest
                          ? Colors.grey
                          : const Color(0xFF78BF32)),
                  title: Text(loc.t('change_avatar'),
                      style: TextStyle(
                          color: _hasPendingPhotoRequest
                              ? Colors.grey
                              : themeProvider.textColor)),
                  onTap: _hasPendingPhotoRequest
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showAvatarOptionsDialog();
                        },
                  enabled: !_hasPendingPhotoRequest,
                ),
              if (!_usePhoto)
                ListTile(
                  leading: Icon(Icons.photo,
                      color: _hasPendingPhotoRequest
                          ? Colors.grey
                          : const Color(0xFF78BF32)),
                  title: Text(loc.t('upload_photo'),
                      style: TextStyle(
                          color: _hasPendingPhotoRequest
                              ? Colors.grey
                              : themeProvider.textColor)),
                  onTap: _hasPendingPhotoRequest
                      ? null
                      : () {
                          Navigator.pop(context);
                          _pickAndUploadImage();
                        },
                  enabled: !_hasPendingPhotoRequest,
                ),
              if (_usePhoto)
                ListTile(
                  leading: Icon(Icons.person,
                      color: _hasPendingPhotoRequest
                          ? Colors.grey
                          : const Color(0xFF78BF32)),
                  title: Text(loc.t('set_avatar'),
                      style: TextStyle(
                          color: _hasPendingPhotoRequest
                              ? Colors.grey
                              : themeProvider.textColor)),
                  onTap: _hasPendingPhotoRequest
                      ? null
                      : () async {
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
                  enabled: !_hasPendingPhotoRequest,
                ),
              if (_usePhoto)
                ListTile(
                  leading: Icon(Icons.photo,
                      color: _hasPendingPhotoRequest
                          ? Colors.grey
                          : const Color(0xFF78BF32)),
                  title: Text(loc.t('change_photo'),
                      style: TextStyle(
                          color: _hasPendingPhotoRequest
                              ? Colors.grey
                              : themeProvider.textColor)),
                  onTap: _hasPendingPhotoRequest
                      ? null
                      : () {
                          Navigator.pop(context);
                          _pickAndUploadImage();
                        },
                  enabled: !_hasPendingPhotoRequest,
                ),
              if (_usePhoto)
                ListTile(
                  leading: Icon(Icons.delete,
                      color:
                          _hasPendingPhotoRequest ? Colors.grey : Colors.red),
                  title: Text(loc.t('delete_photo'),
                      style: TextStyle(
                          color: _hasPendingPhotoRequest
                              ? Colors.grey
                              : themeProvider.textColor)),
                  onTap: _hasPendingPhotoRequest
                      ? null
                      : () async {
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
                  enabled: !_hasPendingPhotoRequest,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAvatarOptionsDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    // Variables temporales para la selección
    String tempSelectedIcon = _selectedIcon;
    String tempAvatarColor = _avatarColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: themeProvider.cardBgColor,
              title: Text(loc.t('customize_avatar'),
                  style: TextStyle(color: themeProvider.textColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vista previa del avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _parseColor(tempAvatarColor),
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconData(tempSelectedIcon),
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.t('select_icon'),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: themeProvider.textColor),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                              setDialogState(() {
                                tempSelectedIcon = iconName;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tempSelectedIcon == iconName
                                    ? _parseColor(tempAvatarColor)
                                    : (themeProvider.isDarkMode
                                        ? const Color(0xFF3A3A3C)
                                        : Colors.grey[200]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: tempSelectedIcon == iconName
                                      ? _parseColor(tempAvatarColor)
                                      : (themeProvider.isDarkMode
                                          ? Colors.grey[600]!
                                          : Colors.grey),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getIconData(iconName),
                                size: 22,
                                color: tempSelectedIcon == iconName
                                    ? Colors.white
                                    : (themeProvider.isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.black54),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.t('select_color'),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: themeProvider.textColor),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                              setDialogState(() {
                                tempAvatarColor = color;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _parseColor(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: tempAvatarColor == color
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: tempAvatarColor == color
                                    ? [
                                        BoxShadow(
                                          color: _parseColor(color)
                                              .withOpacity(0.4),
                                          spreadRadius: 2,
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    loc.t('cancel'),
                    style: TextStyle(color: themeProvider.secondaryTextColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIcon = tempSelectedIcon;
                      _avatarColor = tempAvatarColor;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(loc.t('confirm')),
                ),
              ],
            );
          },
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
      size: 50,
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
      // Validar tamaño y peso de la imagen
      final file = File(image.path);
      final sizeInBytes = file.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      // Limitar tamaño de imagen (ej: 5 MB)
      const maxSizeMB = 5;
      // Limitar dimensiones (ej: 4000x4000 píxeles)
      const maxDimension = 4000;
      final loc = AppLocalizations.of(context)!;

      if (sizeInMB > maxSizeMB) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('image_too_heavy')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtener dimensiones de la imagen
      final imageFile = await decodeImageFromList(await file.readAsBytes());
      if (imageFile.width > maxDimension || imageFile.height > maxDimension) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('image_too_large')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convertir imagen a base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Enviar solicitud de cambio de foto
      try {
        final response = await http.post(
          Uri.parse('${Config.baseUrl}/api/user/photo-change-request'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_email': widget.userEmail,
            'new_avatar_image': 'data:image/jpeg;base64,$base64Image',
          }),
        );

        if (response.statusCode == 200) {
          setState(() {
            _hasPendingPhotoRequest = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Solicitud de cambio de foto enviada. Esperando aprobación'),
              backgroundColor: const Color(0xFF78BF32),
            ),
          );
        } else {
          final error = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error['error'] ?? 'Error al enviar solicitud'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasChanges() {
    // Comparar datos básicos
    if (_nameController.text.trim() != _originalName) return true;
    if (_lastNameController.text.trim() != _originalLastName) return true;
    if (_completePhone != _originalPhone) return true;
    if (_selectedGender != _originalGender) return true;
    if (_birthDate != _originalBirthDate) return true;

    // Comparar avatar
    if (_avatarColor != _originalAvatarColor) return true;
    if (_selectedIcon != _originalAvatarIcon) return true;
    if (_usePhoto != _originalUsePhoto) return true;
    if (_usePhoto && _avatarImage != _originalAvatarImage) return true;

    // Comparar imagen seleccionada
    if (_selectedImage != null) return true;

    return false;
  }

  void _showGenderPicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    final genderOptions = _getGenderOptions(loc);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Título
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        loc.t('select_your_gender'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.t('this_info_required'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                // Opciones
                ...genderOptions.map((option) {
                  final isSelected = _selectedGender == option['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGender = option['value'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? const Color(0xFF78BF32)
                                : themeProvider.secondaryTextColor,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            option['label']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF78BF32)
                                  : themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBirthDatePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    DateTime? tempBirthDate = _birthDate;
    String? tempError;

    // Calcular la fecha máxima (hace 18 años)
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                decoration: BoxDecoration(
                  color: themeProvider.cardBgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Título
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            loc.t('birth_date'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.t('must_be_18'),
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: themeProvider.borderColor),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempBirthDate ?? maxDate,
                        minimumDate: DateTime(1900, 1, 1),
                        maximumDate: maxDate,
                        onDateTimeChanged: (DateTime newDate) {
                          tempBirthDate = newDate;
                          // No hay error porque el máximo ya está limitado a 18 años
                          tempError = null;
                        },
                      ),
                    ),
                    // Mensaje de error
                    if (tempError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tempError!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            if (tempBirthDate == null) {
                              setModalState(() {
                                tempError = loc.t('please_select_birth_date');
                              });
                              return;
                            }

                            // Verificar edad
                            final now = DateTime.now();
                            final age = now.year -
                                tempBirthDate!.year -
                                (now.month > tempBirthDate!.month ||
                                        (now.month == tempBirthDate!.month &&
                                            now.day >= tempBirthDate!.day)
                                    ? 0
                                    : 1);

                            if (age < 18) {
                              setModalState(() {
                                tempError = loc.t('must_be_18_to_use');
                              });
                              return;
                            }

                            // Todo bien, guardar y cerrar
                            setState(() {
                              _birthDate = tempBirthDate;
                              _birthDateError = null;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78BF32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.t('confirm'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('my_data'),
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 24,
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
                      const SizedBox(height: 10),
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _parseColor(_avatarColor),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: themeProvider.isDarkMode
                                    ? themeProvider.cardBgColor
                                    : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeProvider.shadowColor,
                                  spreadRadius: 3,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _usePhoto
                                ? (_selectedImage != null
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
                                              gaplessPlayback: true,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return _getIconWidget();
                                              },
                                            ),
                                          )
                                        : _getIconWidget())
                                : _getIconWidget(),
                          ),
                          GestureDetector(
                            onTap: _showAvatarOptions,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF78BF32),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeProvider.isDarkMode
                                      ? themeProvider.cardBgColor
                                      : Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: themeProvider.shadowColor,
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Campo Nombre
                      Container(
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
                        child: TextFormField(
                          controller: _nameController,
                          maxLength: 20,
                          style: TextStyle(color: themeProvider.textColor),
                          decoration: InputDecoration(
                            labelText: loc.t('name'),
                            labelStyle: TextStyle(
                                color: themeProvider.secondaryTextColor),
                            prefixIcon: const Icon(Icons.person_outline,
                                color: Color(0xFF78BF32)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.t('please_enter_name');
                            }
                            if (value.trim().length > 20) {
                              return loc.t('name_max_length');
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Apellido
                      Container(
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
                        child: TextFormField(
                          controller: _lastNameController,
                          maxLength: 20,
                          style: TextStyle(color: themeProvider.textColor),
                          decoration: InputDecoration(
                            labelText: loc.t('last_name'),
                            labelStyle: TextStyle(
                                color: themeProvider.secondaryTextColor),
                            prefixIcon: const Icon(Icons.person_outline,
                                color: Color(0xFF78BF32)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.t('please_enter_last_name');
                            }
                            if (value.trim().length > 20) {
                              return loc.t('last_name_max_length');
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Email (solo lectura)
                      Container(
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey[100],
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
                        child: TextFormField(
                          controller: _emailController,
                          enabled: false,
                          style: TextStyle(
                              color: themeProvider.secondaryTextColor),
                          decoration: InputDecoration(
                            labelText: loc.t('email'),
                            labelStyle: TextStyle(
                                color: themeProvider.secondaryTextColor),
                            prefixIcon: Icon(Icons.email_outlined,
                                color: themeProvider.secondaryTextColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Teléfono con selector de país
                      Container(
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
                        child: IntlPhoneField(
                          key: _phoneFieldKey,
                          controller: _phoneController,
                          style: TextStyle(
                              fontSize: 16, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            labelText: loc.t('phone'),
                            labelStyle: TextStyle(
                                color: themeProvider.secondaryTextColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            counterText: '', // Oculta el contador
                            prefixIcon: const Icon(Icons.phone_outlined,
                                color: Color(0xFF78BF32)),
                          ),
                          keyboardType: TextInputType.phone,
                          dropdownIcon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF78BF32)),
                          dropdownIconPosition: IconPosition.trailing,
                          showCountryFlag: true,
                          showDropdownIcon: true,
                          initialCountryCode: _initialCountryCode,
                          languageCode: loc.locale.languageCode,
                          pickerDialogStyle: PickerDialogStyle(
                            searchFieldInputDecoration: InputDecoration(
                              labelText: loc.t('search_country'),
                              suffixIcon: const Icon(Icons.search),
                            ),
                          ),
                          onChanged: (phone) {
                            setState(() {
                              _completePhone = phone.completeNumber;
                              // phone.countryCode es el código de marcación (ej: +57)
                              _countryCode = phone.countryCode;
                              _phoneNumber = phone.number;
                            });
                          },
                          onCountryChanged: (country) {
                            // Al cambiar de país, limpiar el número
                            setState(() {
                              _countryCode = '+${country.dialCode}';
                              _countryName = country.name;
                              _phoneNumber = '';
                              _completePhone = '';
                              _phoneController.clear();
                            });
                          },
                          validator: (phone) {
                            if (phone != null && phone.number.isNotEmpty) {
                              // Validación básica del número
                              if (phone.number.length < 6) {
                                return loc.t('phone_too_short');
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Género
                      GestureDetector(
                        onTap: _showGenderPicker,
                        child: Container(
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
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: loc.t('gender'),
                              labelStyle: TextStyle(
                                  color: themeProvider.secondaryTextColor),
                              prefixIcon: const Icon(Icons.wc_outlined,
                                  color: Color(0xFF78BF32)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              errorText: _selectedGender == null
                                  ? loc.t('please_select_gender')
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedGender != null
                                      ? _getGenderOptions(loc).firstWhere(
                                          (opt) =>
                                              opt['value'] == _selectedGender,
                                          orElse: () => {'label': ''},
                                        )['label']!
                                      : loc.t('select'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedGender != null
                                        ? themeProvider.textColor
                                        : themeProvider.secondaryTextColor,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_up,
                                    color: Color(0xFF78BF32)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Fecha de Nacimiento
                      GestureDetector(
                        onTap: _showBirthDatePicker,
                        child: Container(
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
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: loc.t('birth_date'),
                              labelStyle: TextStyle(
                                  color: themeProvider.secondaryTextColor),
                              prefixIcon: const Icon(Icons.cake_outlined,
                                  color: Color(0xFF78BF32)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              errorText: _birthDateError,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _birthDate != null
                                      ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                      : loc.t('select'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _birthDate != null
                                        ? themeProvider.textColor
                                        : themeProvider.secondaryTextColor,
                                  ),
                                ),
                                const Icon(Icons.calendar_today_outlined,
                                    color: Color(0xFF78BF32)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving || !_hasChanges()
                              ? null
                              : _saveUserData,
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
                              : Text(
                                  loc.t('save_changes'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (!_hasChanges())
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            loc.t('no_changes'),
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.red[300]
                                  : Colors.red,
                              fontSize: 12,
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
