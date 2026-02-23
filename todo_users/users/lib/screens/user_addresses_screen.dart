import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';

class UserAddressesScreen extends StatefulWidget {
  final String userEmail;

  const UserAddressesScreen({super.key, required this.userEmail});

  @override
  State<UserAddressesScreen> createState() => _UserAddressesScreenState();
}

class _UserAddressesScreenState extends State<UserAddressesScreen> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;
  bool _isAddingAddress = false;
  bool _isEditingAddress = false;
  int? _editingAddressId;
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Estados para errores de validación
  String? _addressNameError;
  String? _departmentError;
  String? _cityError;
  String? _typeViaError;
  String? _numberPrincipalError;
  String? _numberSecondaryError;
  String? _numberFinalError;
  String? _additionalInfoError;
  String? _addressIconError;
  String? _generalError;
  Map<String, dynamic>? _originalAddress;

  @override
  void initState() {
    super.initState();
    _loadAddresses();

    // Agregar listeners a los controladores de texto para detectar cambios
    _addressNameController.addListener(() => setState(() {}));
    _numberPrincipalController.addListener(() => setState(() {}));
    _numberSecondaryController.addListener(() => setState(() {}));
    _numberFinalController.addListener(() => setState(() {}));
    _additionalInfoController.addListener(() => setState(() {}));
  }

  Future<void> _loadAddresses() async {
    try {
      final response = await http.get(
        Uri.parse(
            '${Config.baseUrl}/user-addresses?user_email=${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _addresses = data['addresses'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando direcciones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateAddress(
      Function(VoidCallback) setDialogState, AppLocalizations loc) {
    // Limpiar errores anteriores
    setDialogState(() {
      _addressNameError = null;
      _departmentError = null;
      _cityError = null;
      _typeViaError = null;
      _numberPrincipalError = null;
      _numberSecondaryError = null;
      _numberFinalError = null;
      _additionalInfoError = null;
      _addressIconError = null;
      _generalError = null;
    });

    // Validar que los campos de números contengan al menos un dígito
    final hasNumber = (String str) => RegExp(r'\d').hasMatch(str);
    bool isValid = true;

    if (_addressNameController.text.isEmpty) {
      setDialogState(() {
        _addressNameError = loc.translate('field_required');
      });
      isValid = false;
    }

    if (_selectedDepartmentId == null) {
      setDialogState(() {
        _departmentError = loc.translate('field_required');
      });
      isValid = false;
    }

    if (_selectedCityId == null) {
      setDialogState(() {
        _cityError = loc.translate('field_required');
      });
      isValid = false;
    }

    if (_selectedTypeVia == null) {
      setDialogState(() {
        _typeViaError = loc.translate('field_required');
      });
      isValid = false;
    }

    if (_numberPrincipalController.text.isEmpty) {
      setDialogState(() {
        _numberPrincipalError = loc.translate('field_required');
      });
      isValid = false;
    } else if (!hasNumber(_numberPrincipalController.text)) {
      setDialogState(() {
        _numberPrincipalError = loc.translate('must_contain_digit');
      });
      isValid = false;
    }

    if (_numberSecondaryController.text.isEmpty) {
      setDialogState(() {
        _numberSecondaryError = loc.translate('field_required');
      });
      isValid = false;
    } else if (!hasNumber(_numberSecondaryController.text)) {
      setDialogState(() {
        _numberSecondaryError = loc.translate('must_contain_digit');
      });
      isValid = false;
    }

    if (_numberFinalController.text.isEmpty) {
      setDialogState(() {
        _numberFinalError = loc.translate('field_required');
      });
      isValid = false;
    } else if (!hasNumber(_numberFinalController.text)) {
      setDialogState(() {
        _numberFinalError = loc.translate('must_contain_digit');
      });
      isValid = false;
    }

    if (_additionalInfoController.text.isEmpty) {
      setDialogState(() {
        _additionalInfoError = loc.translate('field_required');
      });
      isValid = false;
    }

    if (_selectedIcon == null) {
      setDialogState(() {
        _addressIconError = loc.translate('field_required');
      });
      isValid = false;
    }

    return isValid;
  }

  Future<void> _addAddress(
      Function(VoidCallback) setDialogState, AppLocalizations loc) async {
    if (!_validateAddress(setDialogState, loc)) {
      return;
    }

    setDialogState(() {
      _isAddingAddress = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/user-addresses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': widget.userEmail,
          'address_name': _addressNameController.text,
          'department_id': _selectedDepartmentId,
          'city_id': _selectedCityId,
          'type_via': _selectedTypeVia,
          'number_principal': _numberPrincipalController.text,
          'number_secondary': _numberSecondaryController.text.isNotEmpty
              ? _numberSecondaryController.text
              : null,
          'number_final': _numberFinalController.text.isNotEmpty
              ? _numberFinalController.text
              : null,
          'additional_info': _additionalInfoController.text.isNotEmpty
              ? _additionalInfoController.text
              : null,
          'address_icon':
              _selectedIcon != null ? _getIconName(_selectedIcon!) : null,
        }),
      );

      if (response.statusCode == 200) {
        _addressNameController.clear();
        _selectedIcon = null;
        _selectedDepartmentId = null;
        _selectedCityId = null;
        _selectedTypeVia = null;
        _numberPrincipalController.clear();
        _numberSecondaryController.clear();
        _numberFinalController.clear();
        _additionalInfoController.clear();
        _cities.clear();
        _loadAddresses();
        Navigator.pop(context);
      } else {
        final errorData = json.decode(response.body);
        setDialogState(() {
          _generalError = errorData['error'];
        });
      }
    } catch (e) {
      print('Error agregando dirección: $e');
      setDialogState(() {
        _generalError = loc.translate('error_adding_address');
      });
    } finally {
      setDialogState(() {
        _isAddingAddress = false;
      });
    }
  }

  Future<void> _updateAddress(
      Function(VoidCallback) setDialogState, AppLocalizations loc) async {
    if (_editingAddressId == null) return;

    if (!_validateAddress(setDialogState, loc)) {
      return;
    }

    setDialogState(() {
      _isEditingAddress = true;
    });

    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/user-addresses/$_editingAddressId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'address_name': _addressNameController.text,
          'department_id': _selectedDepartmentId,
          'city_id': _selectedCityId,
          'type_via': _selectedTypeVia,
          'number_principal': _numberPrincipalController.text,
          'number_secondary': _numberSecondaryController.text.isNotEmpty
              ? _numberSecondaryController.text
              : null,
          'number_final': _numberFinalController.text.isNotEmpty
              ? _numberFinalController.text
              : null,
          'additional_info': _additionalInfoController.text.isNotEmpty
              ? _additionalInfoController.text
              : null,
          'address_icon':
              _selectedIcon != null ? _getIconName(_selectedIcon!) : null,
        }),
      );

      if (response.statusCode == 200) {
        _addressNameController.clear();
        _selectedIcon = null;
        _selectedDepartmentId = null;
        _selectedCityId = null;
        _selectedTypeVia = null;
        _numberPrincipalController.clear();
        _numberSecondaryController.clear();
        _numberFinalController.clear();
        _additionalInfoController.clear();
        _cities.clear();
        _editingAddressId = null;
        _loadAddresses();
        Navigator.pop(context);
      } else {
        final errorData = json.decode(response.body);
        setDialogState(() {
          _generalError = errorData['error'];
        });
      }
    } catch (e) {
      print('Error actualizando dirección: $e');
      setDialogState(() {
        _generalError = loc.translate('error_updating_address');
      });
    } finally {
      setDialogState(() {
        _isEditingAddress = false;
      });
    }
  }

  Future<void> _deleteAddress(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}/user-addresses/$id'),
      );

      if (response.statusCode == 200) {
        _loadAddresses();
      }
    } catch (e) {
      print('Error eliminando dirección: $e');
    }
  }

  IconData? _selectedIcon;

  final List<Map<String, dynamic>> _addressIcons = [
    {'name': 'Casa', 'icon': Icons.home},
    {'name': 'Apartamento', 'icon': Icons.apartment},
    {'name': 'Empresa', 'icon': Icons.work},
    {'name': 'Colegio', 'icon': Icons.school},
    {'name': 'Tienda', 'icon': Icons.store},
    {'name': 'Iglesia', 'icon': Icons.account_balance},
    {'name': 'Hospital', 'icon': Icons.local_hospital},
    {'name': 'Restaurante', 'icon': Icons.restaurant},
    {'name': 'Hotel', 'icon': Icons.hotel},
    {'name': 'Gimnasio', 'icon': Icons.fitness_center},
    {'name': 'Parque', 'icon': Icons.park},
    {'name': 'Finca', 'icon': Icons.villa},
  ];

  List<dynamic> _departments = [];
  List<dynamic> _cities = [];
  int? _selectedDepartmentId;
  int? _selectedCityId;
  String? _selectedTypeVia;
  final TextEditingController _numberPrincipalController =
      TextEditingController();
  final TextEditingController _numberSecondaryController =
      TextEditingController();
  final TextEditingController _numberFinalController = TextEditingController();
  final TextEditingController _additionalInfoController =
      TextEditingController();

  final List<String> _typeViaOptions = [
    'Calle',
    'Carrera',
    'Avenida',
    'Diagonal',
    'Transversal',
    'Circular',
    'Autopista',
    'Carretera',
    'Camino'
  ];

  // Métodos helper para obtener traducciones
  String _getTranslatedIconName(String name, AppLocalizations loc) {
    final Map<String, String> iconTranslations = {
      'Casa': loc.translate('icon_home'),
      'Apartamento': loc.translate('icon_apartment'),
      'Empresa': loc.translate('icon_company'),
      'Colegio': loc.translate('icon_school'),
      'Tienda': loc.translate('icon_store'),
      'Iglesia': loc.translate('icon_church'),
      'Hospital': loc.translate('icon_hospital'),
      'Restaurante': loc.translate('icon_restaurant'),
      'Hotel': loc.translate('icon_hotel'),
      'Gimnasio': loc.translate('icon_gym'),
      'Parque': loc.translate('icon_park'),
      'Finca': loc.translate('icon_farm'),
    };
    return iconTranslations[name] ?? name;
  }

  String _getTranslatedViaName(String name, AppLocalizations loc) {
    final Map<String, String> viaTranslations = {
      'Calle': loc.translate('via_street'),
      'Carrera': loc.translate('via_race'),
      'Avenida': loc.translate('via_avenue'),
      'Diagonal': loc.translate('via_diagonal'),
      'Transversal': loc.translate('via_transversal'),
      'Circular': loc.translate('via_circular'),
      'Autopista': loc.translate('via_highway'),
      'Carretera': loc.translate('via_road'),
      'Camino': loc.translate('via_path'),
    };
    return viaTranslations[name] ?? name;
  }

  Future<void> _loadDepartments() async {
    try {
      final response =
          await http.get(Uri.parse('${Config.baseUrl}/departments'));
      if (response.statusCode == 200) {
        setState(() {
          _departments = json.decode(response.body)['departments'];
        });
        print('Departamentos cargados: ${_departments.length}');
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
    }
  }

  Future<List<dynamic>> _loadCities(int departmentId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/cities?department_id=$departmentId'),
      );
      if (response.statusCode == 200) {
        final cities = json.decode(response.body)['cities'];
        print('Ciudades cargadas: ${cities.length}');
        return cities;
      }
    } catch (e) {
      print('Error al cargar ciudades: $e');
    }
    return [];
  }

  void _showDepartmentPicker(
      Function(VoidCallback) setDialogState, AppLocalizations loc) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    loc.translate('department_label'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                Expanded(
                  child: ListView.builder(
                    itemCount: _departments.length,
                    itemBuilder: (context, index) {
                      final department = _departments[index];
                      final isSelected =
                          _selectedDepartmentId == department['id'];
                      return InkWell(
                        onTap: () async {
                          final cities = await _loadCities(department['id']);
                          setDialogState(() {
                            _selectedDepartmentId = department['id'];
                            _selectedCityId = null;
                            _cities = cities;
                            _departmentError = null;
                            _cityError = null;
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
                                department['name'],
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
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCityPicker(
      Function(VoidCallback) setDialogState, AppLocalizations loc) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (_selectedDepartmentId == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    loc.translate('city_label'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                Expanded(
                  child: _cities.isEmpty
                      ? Center(
                          child: Text(
                            loc.translate('no_cities_available'),
                            style: TextStyle(
                                color: themeProvider.secondaryTextColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _cities.length,
                          itemBuilder: (context, index) {
                            final city = _cities[index];
                            final isSelected = _selectedCityId == city['id'];
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  _selectedCityId = city['id'];
                                  _cityError = null;
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
                                      city['name'],
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
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTypeViaPicker(
      Function(VoidCallback) setDialogState, AppLocalizations loc) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    loc.translate('type_via_label'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                Expanded(
                  child: ListView.builder(
                    itemCount: _typeViaOptions.length,
                    itemBuilder: (context, index) {
                      final typeVia = _typeViaOptions[index];
                      final isSelected = _selectedTypeVia == typeVia;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            _selectedTypeVia = typeVia;
                            _typeViaError = null;
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
                                _getTranslatedViaName(typeVia, loc),
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
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddAddressDialog() async {
    _selectedIcon = null;
    _selectedDepartmentId = null;
    _selectedCityId = null;
    _selectedTypeVia = null;
    _numberPrincipalController.clear();
    _numberSecondaryController.clear();
    _numberFinalController.clear();
    _additionalInfoController.clear();
    _cities.clear();
    // Limpiar errores de validación
    setState(() {
      _addressNameError = null;
      _departmentError = null;
      _cityError = null;
      _typeViaError = null;
      _numberPrincipalError = null;
      _numberSecondaryError = null;
      _numberFinalError = null;
      _additionalInfoError = null;
      _addressIconError = null;
      _generalError = null;
    });

    print('Cargando departamentos...');
    await _loadDepartments();
    print('Departamentos cargados: ${_departments.length}');
    print('Departamentos: $_departments');

    if (!mounted) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: themeProvider.scaffoldBgColor,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      loc.translate('add_address'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Address Name Field
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
                      border: Border.all(
                        color: _addressNameError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _addressNameController,
                      style: TextStyle(color: themeProvider.textColor),
                      decoration: InputDecoration(
                        labelText: loc.translate('address_name_label'),
                        labelStyle: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 13),
                        hintText: loc.translate('address_name_hint'),
                        prefixIcon: const Icon(Icons.label_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        counterText: '', // Oculta el contador
                      ),
                      maxLength: 25,
                      onChanged: (value) {
                        if (_addressNameError != null) {
                          setDialogState(() {
                            _addressNameError = null;
                          });
                        }
                        // Actualizar estado para reevaluar _hasChanges()
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_addressNameError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _addressNameError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Department and City Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _showDepartmentPicker(setDialogState, loc),
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
                              border: Border.all(
                                color: _departmentError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('department_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedDepartmentId != null
                                            ? _departments.firstWhere(
                                                (d) =>
                                                    d['id'] ==
                                                    _selectedDepartmentId,
                                                orElse: () => {'name': ''},
                                              )['name']
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedDepartmentId != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_up,
                                      color: Color(0xFF78BF32), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectedDepartmentId != null
                              ? () => _showCityPicker(setDialogState, loc)
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedDepartmentId != null
                                  ? themeProvider.cardBgColor
                                  : themeProvider.cardBgColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: themeProvider.shadowColor,
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: _cityError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('city_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedCityId != null
                                            ? _cities.firstWhere(
                                                (c) =>
                                                    c['id'] == _selectedCityId,
                                                orElse: () => {'name': ''},
                                              )['name']
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedCityId != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_up,
                                      color: _selectedDepartmentId != null
                                          ? const Color(0xFF78BF32)
                                          : themeProvider.secondaryTextColor
                                              .withOpacity(0.5),
                                      size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_departmentError != null || _cityError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _departmentError ?? _cityError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Type Via and Number Principal Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showTypeViaPicker(setDialogState, loc),
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
                              border: Border.all(
                                color: _typeViaError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('type_via_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedTypeVia != null
                                            ? _getTranslatedViaName(
                                                _selectedTypeVia!, loc)
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedTypeVia != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_up,
                                      color: Color(0xFF78BF32), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                            border: Border.all(
                              color: _numberPrincipalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberPrincipalController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_principal_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberPrincipalError != null) {
                                setDialogState(() {
                                  _numberPrincipalError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_typeViaError != null || _numberPrincipalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _typeViaError ?? _numberPrincipalError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Number Secondary and Number Final Row
                  Row(
                    children: [
                      Expanded(
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
                            border: Border.all(
                              color: _numberSecondaryError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberSecondaryController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_secondary_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberSecondaryError != null) {
                                setDialogState(() {
                                  _numberSecondaryError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                            border: Border.all(
                              color: _numberFinalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberFinalController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_final_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberFinalError != null) {
                                setDialogState(() {
                                  _numberFinalError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_numberSecondaryError != null ||
                      _numberFinalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _numberSecondaryError ?? _numberFinalError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Additional Info Field
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
                      border: Border.all(
                        color: _additionalInfoError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _additionalInfoController,
                      style: TextStyle(color: themeProvider.textColor),
                      decoration: InputDecoration(
                        labelText: loc.translate('additional_info_label'),
                        labelStyle: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 14),
                        hintText: loc.translate('additional_info_hint'),
                        prefixIcon: const Icon(Icons.info_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        counterText: '', // Oculta el contador
                      ),
                      maxLines: null, // Permite múltiples líneas
                      maxLength: 60, // Límite de 60 caracteres
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) {
                        if (_additionalInfoError != null) {
                          setDialogState(() {
                            _additionalInfoError = null;
                          });
                        }
                        // Actualizar estado para reevaluar _hasChanges()
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_additionalInfoError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _additionalInfoError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Icon Selection
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
                      border: Border.all(
                        color: _addressIconError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('icon_label'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _addressIcons.length,
                          itemBuilder: (context, index) {
                            final iconData = _addressIcons[index];
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _selectedIcon = iconData['icon'];
                                  _addressIconError = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedIcon == iconData['icon']
                                      ? const Color(0xFF78BF32).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _selectedIcon == iconData['icon']
                                        ? const Color(0xFF78BF32)
                                        : themeProvider.borderColor,
                                  ),
                                ),
                                child: Icon(
                                  iconData['icon'],
                                  size: 16,
                                  color: const Color(0xFF78BF32),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_addressIconError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _addressIconError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _addressNameController.clear();
                            _selectedIcon = null;
                            _selectedDepartmentId = null;
                            _selectedCityId = null;
                            _selectedTypeVia = null;
                            _numberPrincipalController.clear();
                            _numberSecondaryController.clear();
                            _numberFinalController.clear();
                            _additionalInfoController.clear();
                            _cities.clear();
                            // Limpiar errores de validación
                            setState(() {
                              _numberPrincipalError = null;
                              _numberSecondaryError = null;
                              _numberFinalError = null;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.cardBgColor,
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            loc.translate('cancel_btn'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isAddingAddress
                              ? null
                              : () => _addAddress(setDialogState, loc),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78BF32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isAddingAddress
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  loc.translate('add_btn'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  // Error Message
                  if (_generalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      child: Text(
                        _generalError!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditAddressDialog(Map<String, dynamic> address) async {
    _editingAddressId = address['id'];
    _originalAddress = Map.from(address); // Guardar dirección original
    _addressNameController.text = address['address_name'];
    _selectedIcon = address['address_icon'] != null
        ? _getIconFromString(address['address_icon'])
        : null;
    _selectedDepartmentId = address['department_id'];
    _selectedCityId = address['city_id'];
    _selectedTypeVia = address['type_via'];
    _numberPrincipalController.text =
        address['number_principal']?.toString() ?? '';
    _numberSecondaryController.text =
        address['number_secondary']?.toString() ?? '';
    _numberFinalController.text = address['number_final']?.toString() ?? '';
    _additionalInfoController.text = address['additional_info'] ?? '';
    _cities.clear();
    // Limpiar errores de validación
    setState(() {
      _addressNameError = null;
      _departmentError = null;
      _cityError = null;
      _typeViaError = null;
      _numberPrincipalError = null;
      _numberSecondaryError = null;
      _numberFinalError = null;
      _additionalInfoError = null;
      _addressIconError = null;
      _generalError = null;
    });

    await _loadDepartments();
    if (_selectedDepartmentId != null) {
      _cities = await _loadCities(_selectedDepartmentId!);
    }

    if (!mounted) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: themeProvider.scaffoldBgColor,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    loc.translate('edit_address'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Address Name Field
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
                      border: Border.all(
                        color: _addressNameError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _addressNameController,
                      style: TextStyle(color: themeProvider.textColor),
                      decoration: InputDecoration(
                        labelText: loc.translate('address_name_label'),
                        labelStyle: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 13),
                        hintText: loc.translate('address_name_hint'),
                        prefixIcon: const Icon(Icons.label_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        counterText: '', // Oculta el contador
                      ),
                      maxLength: 25,
                      onChanged: (value) {
                        if (_addressNameError != null) {
                          setDialogState(() {
                            _addressNameError = null;
                          });
                        }
                        // Actualizar estado para reevaluar _hasChanges()
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_addressNameError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _addressNameError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Department and City Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _showDepartmentPicker(setDialogState, loc),
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
                              border: Border.all(
                                color: _departmentError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('department_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedDepartmentId != null
                                            ? _departments.firstWhere(
                                                (d) =>
                                                    d['id'] ==
                                                    _selectedDepartmentId,
                                                orElse: () => {'name': ''},
                                              )['name']
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedDepartmentId != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_up,
                                      color: Color(0xFF78BF32), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectedDepartmentId != null
                              ? () => _showCityPicker(setDialogState, loc)
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedDepartmentId != null
                                  ? themeProvider.cardBgColor
                                  : themeProvider.cardBgColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: themeProvider.shadowColor,
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: _cityError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('city_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedCityId != null
                                            ? _cities.firstWhere(
                                                (c) =>
                                                    c['id'] == _selectedCityId,
                                                orElse: () => {'name': ''},
                                              )['name']
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedCityId != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_up,
                                      color: _selectedDepartmentId != null
                                          ? const Color(0xFF78BF32)
                                          : themeProvider.secondaryTextColor
                                              .withOpacity(0.5),
                                      size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_departmentError != null || _cityError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _departmentError ?? _cityError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Type Via and Number Principal Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showTypeViaPicker(setDialogState, loc),
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
                              border: Border.all(
                                color: _typeViaError != null
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: loc.translate('type_via_label'),
                                labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: themeProvider.secondaryTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _selectedTypeVia != null
                                            ? _getTranslatedViaName(
                                                _selectedTypeVia!, loc)
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedTypeVia != null
                                              ? themeProvider.textColor
                                              : themeProvider
                                                  .secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_up,
                                      color: Color(0xFF78BF32), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                            border: Border.all(
                              color: _numberPrincipalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberPrincipalController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_principal_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberPrincipalError != null) {
                                setDialogState(() {
                                  _numberPrincipalError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_typeViaError != null || _numberPrincipalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _typeViaError ?? _numberPrincipalError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Number Secondary and Number Final Row
                  Row(
                    children: [
                      Expanded(
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
                            border: Border.all(
                              color: _numberSecondaryError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberSecondaryController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_secondary_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberSecondaryError != null) {
                                setDialogState(() {
                                  _numberSecondaryError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                            border: Border.all(
                              color: _numberFinalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberFinalController,
                            style: TextStyle(color: themeProvider.textColor),
                            decoration: InputDecoration(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  loc.translate('number_final_label'),
                                  style: TextStyle(
                                    color: themeProvider.secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              counterText: '', // Oculta el contador
                            ),
                            keyboardType: TextInputType.text,
                            maxLength: 8,
                            onChanged: (value) {
                              if (_numberFinalError != null) {
                                setDialogState(() {
                                  _numberFinalError = null;
                                });
                              }
                              // Actualizar estado para reevaluar _hasChanges()
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_numberSecondaryError != null ||
                      _numberFinalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _numberSecondaryError ?? _numberFinalError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Additional Info Field
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
                      border: Border.all(
                        color: _additionalInfoError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _additionalInfoController,
                      style: TextStyle(color: themeProvider.textColor),
                      decoration: InputDecoration(
                        labelText: loc.translate('additional_info_label'),
                        labelStyle: TextStyle(
                            color: themeProvider.secondaryTextColor,
                            fontSize: 14),
                        hintText: loc.translate('additional_info_hint'),
                        prefixIcon: const Icon(Icons.info_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        counterText: '', // Oculta el contador
                      ),
                      maxLines: null, // Permite múltiples líneas
                      maxLength: 60, // Límite de 60 caracteres
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) {
                        if (_additionalInfoError != null) {
                          setDialogState(() {
                            _additionalInfoError = null;
                          });
                        }
                        // Actualizar estado para reevaluar _hasChanges()
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_additionalInfoError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _additionalInfoError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Icon Selection
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
                      border: Border.all(
                        color: _addressIconError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('icon_label'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _addressIcons.length,
                          itemBuilder: (context, index) {
                            final iconData = _addressIcons[index];
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _selectedIcon = iconData['icon'];
                                  _addressIconError = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedIcon == iconData['icon']
                                      ? const Color(0xFF78BF32).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _selectedIcon == iconData['icon']
                                        ? const Color(0xFF78BF32)
                                        : themeProvider.borderColor,
                                  ),
                                ),
                                child: Icon(
                                  iconData['icon'],
                                  size: 16,
                                  color: const Color(0xFF78BF32),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_addressIconError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        _addressIconError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _addressNameController.clear();
                            _addressController.clear();
                            _editingAddressId = null;
                            _selectedIcon = null;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.cardBgColor,
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            loc.translate('cancel_btn'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isEditingAddress || !_hasChanges()
                              ? null
                              : () => _updateAddress(setDialogState, loc),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasChanges()
                                ? const Color(0xFF78BF32)
                                : (themeProvider.isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300]),
                            foregroundColor: _hasChanges()
                                ? Colors.white
                                : (themeProvider.isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600]),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isEditingAddress
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  loc.translate('save_btn'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (!_hasChanges())
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        loc.translate('no_changes'),
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.red[300]
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  // Error Message
                  if (_generalError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      child: Text(
                        _generalError!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddressDetailsDialog(Map<String, dynamic> address) {
    final addressIcon = address['address_icon'] != null
        ? _getIconFromString(address['address_icon'])
        : Icons.location_on;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: themeProvider.scaffoldBgColor,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF78BF32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        addressIcon,
                        size: 24,
                        color: const Color(0xFF78BF32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        address['address_name'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 24),
                // Address Details
                Container(
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Address
                      Text(
                        '${_getTranslatedViaName(address['type_via'], loc)} ${address['number_principal']}'
                        '${address['number_secondary'] != null ? ' #${address['number_secondary']}' : ''}'
                        '${address['number_final'] != null ? ' - ${address['number_final']}' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: themeProvider.textColor,
                        ),
                      ),
                      // Additional Info
                      if (address['additional_info'] != null &&
                          address['additional_info'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            address['additional_info'],
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.secondaryTextColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Location
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF78BF32),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${address['city_name']}, ${address['department_name']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: themeProvider.secondaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Close Button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                  ),
                  child: Text(
                    loc.translate('close_btn'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(int id) {
    final addressToDelete = _addresses.firstWhere((addr) => addr['id'] == id);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: themeProvider.scaffoldBgColor,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  loc.translate('delete_address_title'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Content
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.secondaryTextColor,
                    ),
                    children: [
                      TextSpan(
                          text: '${loc.translate('delete_address_confirm')} '),
                      TextSpan(
                        text: addressToDelete['address_name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.cardBgColor,
                          foregroundColor: themeProvider.textColor,
                          side: BorderSide(color: themeProvider.borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          loc.translate('cancel_btn'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteAddress(id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          loc.translate('delete_btn'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  bool _hasChanges() {
    if (_originalAddress == null) return true;

    print('=== Comparando cambios ===');
    print(
        'Nombre: ${_addressNameController.text} vs ${_originalAddress!['address_name']}');
    print(
        'Número principal: ${_numberPrincipalController.text} vs ${_originalAddress!['number_principal']}');
    print(
        'Número secundario: ${_numberSecondaryController.text} vs ${_originalAddress!['number_secondary']}');
    print(
        'Número final: ${_numberFinalController.text} vs ${_originalAddress!['number_final']}');
    print(
        'Info adicional: ${_additionalInfoController.text} vs ${_originalAddress!['additional_info']}');
    print(
        'Departamento: ${_selectedDepartmentId} vs ${_originalAddress!['department_id']}');
    print('Ciudad: ${_selectedCityId} vs ${_originalAddress!['city_id']}');
    print('Tipo vía: ${_selectedTypeVia} vs ${_originalAddress!['type_via']}');

    // Comparar campos de texto
    if (_addressNameController.text != _originalAddress!['address_name']) {
      print('Cambio en Nombre');
      return true;
    }
    if (_numberPrincipalController.text !=
        (_originalAddress!['number_principal']?.toString() ?? '')) {
      print('Cambio en Número principal');
      return true;
    }
    if (_numberSecondaryController.text !=
        (_originalAddress!['number_secondary']?.toString() ?? '')) {
      print('Cambio en Número secundario');
      return true;
    }
    if (_numberFinalController.text !=
        (_originalAddress!['number_final']?.toString() ?? '')) {
      print('Cambio en Número final');
      return true;
    }
    if (_additionalInfoController.text !=
        (_originalAddress!['additional_info'] ?? '')) {
      print('Cambio en Info adicional');
      return true;
    }

    // Comparar valores seleccionados
    if (_selectedDepartmentId != _originalAddress!['department_id']) {
      print('Cambio en Departamento');
      return true;
    }
    if (_selectedCityId != _originalAddress!['city_id']) {
      print('Cambio en Ciudad');
      return true;
    }
    if (_selectedTypeVia != _originalAddress!['type_via']) {
      print('Cambio en Tipo vía');
      return true;
    }

    // Comparar icono
    final currentIconName =
        _selectedIcon != null ? _getIconName(_selectedIcon!) : null;
    if (currentIconName != _originalAddress!['address_icon']) {
      print(
          'Cambio en Icono: $currentIconName vs ${_originalAddress!['address_icon']}');
      return true;
    }

    print('=== No hay cambios ===');
    return false;
  }

  String _getIconName(IconData iconData) {
    for (final icon in _addressIcons) {
      if (icon['icon'] == iconData) {
        return icon['name'];
      }
    }
    return 'Ubicación';
  }

  String _formatAddress(Map<String, dynamic> address, AppLocalizations loc) {
    final buffer = StringBuffer();
    final translatedVia = _getTranslatedViaName(address['type_via'], loc);
    buffer.write('$translatedVia ${address['number_principal']}');

    if (address['number_secondary'] != null) {
      buffer.write(' #${address['number_secondary']}');
    }

    if (address['number_final'] != null) {
      buffer.write(' - ${address['number_final']}');
    }

    // No mostrar información adicional en la lista
    return buffer.toString();
  }

  IconData _getIconFromString(String? iconName) {
    if (iconName == null) return Icons.location_on;
    for (final icon in _addressIcons) {
      if (icon['name'] == iconName) {
        return icon['icon'];
      }
    }
    return Icons.location_on;
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
          loc.translate('my_addresses'),
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 80,
                          color: themeProvider.secondaryTextColor,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          loc.translate('no_addresses'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.translate('add_first_address'),
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _showAddAddressDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78BF32),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 24,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.translate('add_address'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Address List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _addresses.length,
                            itemBuilder: (context, index) {
                              final address = _addresses[index];
                              return GestureDetector(
                                onTap: () => _showAddressDetailsDialog(address),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: themeProvider.cardBgColor,
                                    borderRadius: BorderRadius.circular(20),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Address Icon
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? const Color(0xFF3A3A3C)
                                              : const Color(0xFFF4F2F2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          address['address_icon'] != null
                                              ? _getIconFromString(
                                                  address['address_icon'])
                                              : Icons.location_on,
                                          size: 32,
                                          color: const Color(0xFF78BF32),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Address Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              address['address_name'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: themeProvider.textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            // Formatted Address
                                            Text(
                                              _formatAddress(address, loc),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: themeProvider
                                                    .secondaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            // Location Info
                                            Text(
                                              '${address['city_name']}, ${address['department_name']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: themeProvider
                                                    .secondaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () =>
                                                _showEditAddressDialog(address),
                                            icon: Icon(
                                              Icons.edit,
                                              color: themeProvider.textColor,
                                              size: 20,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 2),
                                          IconButton(
                                            onPressed: () =>
                                                _showDeleteConfirmDialog(
                                                    address['id']),
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Espacio para que el último elemento no se superponga con el botón flotante
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddAddressDialog,
              backgroundColor: const Color(0xFF78BF32),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 24),
              label: Text(
                loc.translate('add_address'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
