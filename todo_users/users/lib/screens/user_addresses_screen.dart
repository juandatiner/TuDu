import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

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
  String? _generalError;
  Map<String, dynamic>? _originalAddress;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
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

  Future<void> _addAddress(Function(VoidCallback) setDialogState) async {
    // Limpiar errores anteriores
    setDialogState(() {
      _addressNameError = null;
      _departmentError = null;
      _cityError = null;
      _typeViaError = null;
      _numberPrincipalError = null;
      _numberSecondaryError = null;
      _numberFinalError = null;
      _generalError = null;
    });

    // Validar que los campos de números contengan al menos un dígito
    final hasNumber = (String str) => RegExp(r'\d').hasMatch(str);
    bool isValid = true;

    if (_addressNameController.text.isEmpty) {
      setDialogState(() {
        _addressNameError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedDepartmentId == null) {
      setDialogState(() {
        _departmentError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedCityId == null) {
      setDialogState(() {
        _cityError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedTypeVia == null) {
      setDialogState(() {
        _typeViaError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_numberPrincipalController.text.isEmpty) {
      setDialogState(() {
        _numberPrincipalError = 'Campo obligatorio';
      });
      isValid = false;
    } else if (!hasNumber(_numberPrincipalController.text)) {
      setDialogState(() {
        _numberPrincipalError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (_numberSecondaryController.text.isNotEmpty &&
        !hasNumber(_numberSecondaryController.text)) {
      setDialogState(() {
        _numberSecondaryError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (_numberFinalController.text.isNotEmpty &&
        !hasNumber(_numberFinalController.text)) {
      setDialogState(() {
        _numberFinalError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (!isValid) {
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
        _generalError = 'Error al agregar dirección';
      });
    } finally {
      setDialogState(() {
        _isAddingAddress = false;
      });
    }
  }

  Future<void> _updateAddress(Function(VoidCallback) setDialogState) async {
    if (_editingAddressId == null) return;

    // Limpiar errores anteriores
    setDialogState(() {
      _addressNameError = null;
      _departmentError = null;
      _cityError = null;
      _typeViaError = null;
      _numberPrincipalError = null;
      _numberSecondaryError = null;
      _numberFinalError = null;
      _generalError = null;
    });

    // Validar que los campos de números contengan al menos un dígito
    final hasNumber = (String str) => RegExp(r'\d').hasMatch(str);
    bool isValid = true;

    if (_addressNameController.text.isEmpty) {
      setDialogState(() {
        _addressNameError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedDepartmentId == null) {
      setDialogState(() {
        _departmentError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedCityId == null) {
      setDialogState(() {
        _cityError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_selectedTypeVia == null) {
      setDialogState(() {
        _typeViaError = 'Campo obligatorio';
      });
      isValid = false;
    }

    if (_numberPrincipalController.text.isEmpty) {
      setDialogState(() {
        _numberPrincipalError = 'Campo obligatorio';
      });
      isValid = false;
    } else if (!hasNumber(_numberPrincipalController.text)) {
      setDialogState(() {
        _numberPrincipalError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (_numberSecondaryController.text.isNotEmpty &&
        !hasNumber(_numberSecondaryController.text)) {
      setDialogState(() {
        _numberSecondaryError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (_numberFinalController.text.isNotEmpty &&
        !hasNumber(_numberFinalController.text)) {
      setDialogState(() {
        _numberFinalError = 'Debe contener al menos un dígito';
      });
      isValid = false;
    }

    if (!isValid) {
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
        _generalError = 'Error al actualizar dirección';
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
      _generalError = null;
    });

    print('Cargando departamentos...');
    await _loadDepartments();
    print('Departamentos cargados: ${_departments.length}');
    print('Departamentos: $_departments');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFF4F2F2),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'Agregar Dirección',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Address Name Field
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
                      border: Border.all(
                        color: _addressNameError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _addressNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        hintText: 'Casa, Empresa...',
                        prefixIcon: Icon(Icons.label_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        if (_addressNameError != null) {
                          setDialogState(() {
                            _addressNameError = null;
                          });
                        }
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
                        child: Container(
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
                            border: Border.all(
                              color: _departmentError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: DropdownButton<int>(
                            value: _selectedDepartmentId,
                            hint: const Text('Departamento',
                                style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            underline: Container(),
                            items: _departments.map((department) {
                              return DropdownMenuItem<int>(
                                value: department['id'],
                                child: Text(department['name'],
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                print('Seleccionado departamento: $value');
                                final cities = await _loadCities(value);
                                print('Ciudades cargadas: $cities');
                                setDialogState(() {
                                  _selectedDepartmentId = value;
                                  _selectedCityId = null;
                                  _cities = cities;
                                  _departmentError = null;
                                  _cityError = null;
                                });
                              } else {
                                setDialogState(() {
                                  _selectedDepartmentId = null;
                                  _selectedCityId = null;
                                  _cities = [];
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _cityError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: DropdownButton<int>(
                            value: _selectedCityId,
                            hint: const Text('Ciudad',
                                style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            underline: Container(),
                            items: _cities.map((city) {
                              return DropdownMenuItem<int>(
                                value: city['id'],
                                child: Text(city['name'],
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedCityId = value;
                                _cityError = null;
                              });
                            },
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
                        flex: 2,
                        child: Container(
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
                            border: Border.all(
                              color: _typeViaError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          child: DropdownButton<String>(
                            value: _selectedTypeVia,
                            hint: const Text('Tipo de vía',
                                style: TextStyle(fontSize: 14)),
                            isExpanded: true,
                            underline: Container(),
                            items: _typeViaOptions.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type,
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedTypeVia = value;
                                _typeViaError = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _numberPrincipalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberPrincipalController,
                            decoration: InputDecoration(
                              labelText: '# Principal',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberPrincipalError != null) {
                                setDialogState(() {
                                  _numberPrincipalError = null;
                                });
                              }
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
                            border: Border.all(
                              color: _numberSecondaryError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberSecondaryController,
                            decoration: InputDecoration(
                              labelText: '# Secundario',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberSecondaryError != null) {
                                setDialogState(() {
                                  _numberSecondaryError = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _numberFinalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberFinalController,
                            decoration: InputDecoration(
                              labelText: '# Final',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberFinalError != null) {
                                setDialogState(() {
                                  _numberFinalError = null;
                                });
                              }
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
                    child: TextField(
                      controller: _additionalInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Información Adicional',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        hintText: 'ej: Edificio X, Apto 101',
                        prefixIcon: Icon(Icons.info_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Icon Selection
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Icono',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
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
                                        : Colors.grey.withOpacity(0.3),
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
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancelar',
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
                              : () => _addAddress(setDialogState),
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
                              : const Text(
                                  'Agregar',
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
        : _getAddressIcon(address['address_name']);
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
      _generalError = null;
    });

    await _loadDepartments();
    if (_selectedDepartmentId != null) {
      _cities = await _loadCities(_selectedDepartmentId!);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFF4F2F2),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'Editar Dirección',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Address Name Field
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
                      border: Border.all(
                        color: _addressNameError != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _addressNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        hintText: 'Casa, Empresa...',
                        prefixIcon: Icon(Icons.label_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        if (_addressNameError != null) {
                          setDialogState(() {
                            _addressNameError = null;
                          });
                        }
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
                        child: Container(
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
                            border: Border.all(
                              color: _departmentError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: DropdownButton<int>(
                            value: _selectedDepartmentId,
                            hint: const Text('Departamento',
                                style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            underline: Container(),
                            items: _departments.map((department) {
                              return DropdownMenuItem<int>(
                                value: department['id'],
                                child: Text(department['name'],
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                print('Seleccionado departamento: $value');
                                final cities = await _loadCities(value);
                                print('Ciudades cargadas: $cities');
                                setDialogState(() {
                                  _selectedDepartmentId = value;
                                  _selectedCityId = null;
                                  _cities = cities;
                                  _departmentError = null;
                                  _cityError = null;
                                });
                              } else {
                                setDialogState(() {
                                  _selectedDepartmentId = null;
                                  _selectedCityId = null;
                                  _cities = [];
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _cityError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: DropdownButton<int>(
                            value: _selectedCityId,
                            hint: const Text('Ciudad',
                                style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            underline: Container(),
                            items: _cities.map((city) {
                              return DropdownMenuItem<int>(
                                value: city['id'],
                                child: Text(city['name'],
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedCityId = value;
                                _cityError = null;
                              });
                            },
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
                        flex: 2,
                        child: Container(
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
                            border: Border.all(
                              color: _typeViaError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          child: DropdownButton<String>(
                            value: _selectedTypeVia,
                            hint: const Text('Tipo vía',
                                style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            underline: Container(),
                            items: _typeViaOptions.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type,
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedTypeVia = value;
                                _typeViaError = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _numberPrincipalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberPrincipalController,
                            decoration: InputDecoration(
                              labelText: '# Principal',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberPrincipalError != null) {
                                setDialogState(() {
                                  _numberPrincipalError = null;
                                });
                              }
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
                            border: Border.all(
                              color: _numberSecondaryError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberSecondaryController,
                            decoration: InputDecoration(
                              labelText: '# Secundario',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberSecondaryError != null) {
                                setDialogState(() {
                                  _numberSecondaryError = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
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
                            border: Border.all(
                              color: _numberFinalError != null
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _numberFinalController,
                            decoration: InputDecoration(
                              labelText: '# Final',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (value) {
                              if (_numberFinalError != null) {
                                setDialogState(() {
                                  _numberFinalError = null;
                                });
                              }
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
                    child: TextField(
                      controller: _additionalInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Información Adicional',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        hintText: 'ej: Edificio X, Apto 101',
                        prefixIcon: Icon(Icons.info_outline,
                            color: Color(0xFF78BF32), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Icon Selection
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Icono',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
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
                                        : Colors.grey.withOpacity(0.3),
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
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancelar',
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
                          onPressed: _isEditingAddress
                              ? null
                              : () => _updateAddress(setDialogState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78BF32),
                            foregroundColor: Colors.white,
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
                              : const Text(
                                  'Guardar',
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

  void _showDeleteConfirmDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Dirección'),
        content:
            const Text('¿Estás seguro de que quieres eliminar esta dirección?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _getIconName(IconData iconData) {
    for (final icon in _addressIcons) {
      if (icon['icon'] == iconData) {
        return icon['name'];
      }
    }
    return 'Ubicación';
  }

  String _formatAddress(Map<String, dynamic> address) {
    final buffer = StringBuffer();
    buffer.write('${address['type_via']} ${address['number_principal']}');

    if (address['number_secondary'] != null) {
      buffer.write(' #${address['number_secondary']}');
    }

    if (address['number_final'] != null) {
      buffer.write(' - ${address['number_final']}');
    }

    if (address['additional_info'] != null &&
        address['additional_info'].isNotEmpty) {
      buffer.write('. ${address['additional_info']}');
    }

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

  IconData _getAddressIcon(String addressName) {
    final name = addressName.toLowerCase();
    if (name.contains('casa') || name.contains('home')) {
      return Icons.home;
    } else if (name.contains('apartamento') ||
        name.contains('apartamento') ||
        name.contains('apt') ||
        name.contains('piso')) {
      return Icons.apartment;
    } else if (name.contains('finca') ||
        name.contains('hacienda') ||
        name.contains('rancho')) {
      return Icons.villa;
    } else if (name.contains('empresa') ||
        name.contains('empresa') ||
        name.contains('trabajo') ||
        name.contains('work') ||
        name.contains('oficina')) {
      return Icons.work;
    } else if (name.contains('colegio') ||
        name.contains('escuela') ||
        name.contains('universidad') ||
        name.contains('school') ||
        name.contains('instituto')) {
      return Icons.school;
    } else if (name.contains('tienda') ||
        name.contains('store') ||
        name.contains('comercio') ||
        name.contains('tienda')) {
      return Icons.store;
    } else if (name.contains('iglesia') ||
        name.contains('templo') ||
        name.contains('catedral') ||
        name.contains('parroquia')) {
      return Icons.account_balance;
    } else if (name.contains('hospital') ||
        name.contains('clinica') ||
        name.contains('medico')) {
      return Icons.local_hospital;
    } else if (name.contains('restaurante') ||
        name.contains('cafeteria') ||
        name.contains('bar')) {
      return Icons.restaurant;
    } else if (name.contains('hotel') ||
        name.contains('hostal') ||
        name.contains('motel')) {
      return Icons.hotel;
    } else if (name.contains('gym') ||
        name.contains('gimnasio') ||
        name.contains('fitness')) {
      return Icons.fitness_center;
    } else if (name.contains('parque') ||
        name.contains('jardin') ||
        name.contains('plaza')) {
      return Icons.park;
    } else {
      return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Direcciones',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Address Icon
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F2F2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    address['address_icon'] != null
                                        ? _getIconFromString(
                                            address['address_icon'])
                                        : _getAddressIcon(
                                            address['address_name']),
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
                                    children: [
                                      Text(
                                        address['address_name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Formatted Address
                                      Text(
                                        _formatAddress(address),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Location Info
                                      Text(
                                        '${address['city_name']}, ${address['department_name']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Action Buttons
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _showEditAddressDialog(address),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 2),
                                    IconButton(
                                      onPressed: () => _showDeleteConfirmDialog(
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
                          );
                        },
                      ),
                      // Add Address Button
                      GestureDetector(
                        onTap: _showAddAddressDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 32,
                                  color: Color(0xFF78BF32),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Agregar Dirección',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
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
}
