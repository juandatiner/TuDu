import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';

class PublishServiceScreen extends StatefulWidget {
  final String userEmail;

  const PublishServiceScreen({super.key, required this.userEmail});

  @override
  State<PublishServiceScreen> createState() => _PublishServiceScreenState();
}

class _PublishServiceScreenState extends State<PublishServiceScreen> {
  int _selectedQuantity = 1;
  int _selectedUnitIndex = 0;
  String _summary = '';
  bool _showMaxYearWarning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar el resumen con los valores por defecto al cargar la pantalla
    if (_summary.isEmpty) {
      _updateSummary();
    }
  }

  // Variables para validación de campos
  bool _titleError = false;
  bool _descriptionError = false;
  bool _budgetError = false;
  bool _budgetMaxError = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _workerInfoController = TextEditingController();

  final FocusNode _budgetFocusNode = FocusNode();

  final FixedExtentScrollController _quantityController =
      FixedExtentScrollController(initialItem: 5000);
  final FixedExtentScrollController _unitController =
      FixedExtentScrollController(initialItem: 5000);

  // Listas de unidades que se actualizarán dinámicamente según el idioma
  List<String> _units = ['Horas', 'Días', 'Semanas', 'Meses', 'Años'];
  List<String> _unitsSingular = ['Hora', 'Día', 'Semana', 'Mes', 'Año'];

  void _updateUnitsForLanguage(BuildContext context) {
    final loc = AppLocalizations.of(context);
    _units = [
      loc?.translate('hours') ?? 'Horas',
      loc?.translate('days') ?? 'Días',
      loc?.translate('weeks') ?? 'Semanas',
      loc?.translate('months') ?? 'Meses',
      loc?.translate('years') ?? 'Años',
    ];
    _unitsSingular = [
      loc?.translate('hour') ?? 'Hora',
      loc?.translate('day') ?? 'Día',
      loc?.translate('week') ?? 'Semana',
      loc?.translate('month') ?? 'Mes',
      loc?.translate('year') ?? 'Año',
    ];
  }

  Future<void> _publishService() async {
    final loc = AppLocalizations.of(context);

    // Redondear presupuesto a centenas antes de validar
    final budgetText = _budgetController.text.trim();
    final numericBudgetForRounding = budgetText.replaceAll(',', '');
    if (numericBudgetForRounding.isNotEmpty &&
        double.tryParse(numericBudgetForRounding) != null) {
      final number = double.parse(numericBudgetForRounding);
      final roundedNumber = (number / 100).round() * 100;
      final formatted = roundedNumber.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );
      _budgetController.text = formatted;
    }

    // Verificar que tudus los campos estén llenos (sin solo espacios en blanco)
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final budget = _budgetController.text.trim();
    final workerInfo = _workerInfoController.text.trim();

    // Validar campos vacíos
    if (title.isEmpty ||
        description.isEmpty ||
        budget.isEmpty ||
        workerInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.translate('all_fields_required') ??
              'tudus los campos son obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar título (mínimo 3 palabras)
    if (_countWords(title) < 3) {
      setState(() {
        _titleError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.translate('title_min_3_words') ??
              'El título debe tener al menos 3 palabras'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar descripción (mínimo 20 palabras)
    if (_countWords(description) < 20) {
      setState(() {
        _descriptionError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.translate('description_min_20_words') ??
              'La descripción debe tener al menos 20 palabras'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar presupuesto mínimo de 5.000 pesos y máximo de 100.000.000
    final numericBudget = budget.replaceAll(',', '');
    final budgetValue = double.tryParse(numericBudget) ?? 0;
    if (budgetValue < 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.translate('min_budget_error') ??
              'El presupuesto mínimo es de \$5.000 pesos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (budgetValue > 100000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.translate('max_budget_error') ??
              'El presupuesto máximo es de \$100.000.000 de pesos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse('${Config.baseUrl}/publish-service');
    try {
      final body = {
        'user_email': widget.userEmail,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'time_quantity': _selectedQuantity,
        'time_unit': _units[_selectedUnitIndex].toLowerCase(),
        'budget': numericBudget,
        'worker_info': _workerInfoController.text,
      };
      print('Enviando datos: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.translate('service_published_success') ??
                'Servicio publicado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc?.translate('error_publishing_service') ?? 'Error al publicar el servicio'}: ${response.statusCode} - ${response.body}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${loc?.translate('connection_error') ?? 'Error de conexión'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _workerInfoController.dispose();
    _budgetFocusNode.dispose();
    super.dispose();
  }

  // Función para contar palabras
  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // Validar título (mínimo 3 palabras)
  void _validateTitle(String value) {
    final wordCount = _countWords(value);
    setState(() {
      _titleError = wordCount < 3 && value.trim().isNotEmpty;
    });
  }

  // Validar descripción (mínimo 20 palabras)
  void _validateDescription(String value) {
    final wordCount = _countWords(value);
    setState(() {
      _descriptionError = wordCount < 20 && value.trim().isNotEmpty;
    });
  }

  // Validar presupuesto (mínimo 5.000 pesos, máximo 100.000.000)
  void _validateBudget(String value) {
    final numericValue = value.replaceAll(',', '').replaceAll('.', '');
    final number = double.tryParse(numericValue) ?? 0;
    setState(() {
      _budgetError = value.isNotEmpty && number < 5000;
      _budgetMaxError = value.isNotEmpty && number > 100000000;
    });
  }

  void _updateSummary() {
    final loc = AppLocalizations.of(context);

    if (_selectedQuantity == 0) {
      setState(() {
        _summary =
            '${loc?.translate('summary') ?? 'Resumen'}: 0 ${loc?.translate('days') ?? 'días'}';
        _showMaxYearWarning = false;
      });
      return;
    }

    // Si se seleccionaron horas, convertir a días y horas si es mayor a 24
    if (_selectedUnitIndex == 0) {
      setState(() {
        _showMaxYearWarning =
            _selectedQuantity > 24 * 365; // Más de un año en horas
        if (_showMaxYearWarning) {
          _summary =
              '${loc?.translate('summary') ?? 'Resumen'}: ${loc?.translate('max_time_exceeded_summary') ?? 'Tiempo máximo excedido'}';
        } else if (_selectedQuantity < 24) {
          // Menos de 24 horas, mostrar solo horas
          _summary =
              '${loc?.translate('summary') ?? 'Resumen'}: $_selectedQuantity ${_selectedQuantity == 1 ? (loc?.translate('hour') ?? 'hora') : (loc?.translate('hours') ?? 'horas')}';
        } else {
          // Más de 24 horas, convertir a días y horas
          final days = _selectedQuantity ~/ 24;
          final hours = _selectedQuantity % 24;
          final parts = <String>[];

          if (days > 0) {
            parts.add(
                '$days ${days == 1 ? (loc?.translate('day') ?? 'día') : (loc?.translate('days') ?? 'días')}');
          }

          if (hours > 0) {
            parts.add(
                '$hours ${hours == 1 ? (loc?.translate('hour') ?? 'hora') : (loc?.translate('hours') ?? 'horas')}');
          }

          _summary =
              '${loc?.translate('summary') ?? 'Resumen'}: ${parts.join(' y ')}';
        }
      });
      return;
    }

    int totalDays = 0;
    switch (_selectedUnitIndex) {
      case 1: // dias
        totalDays = _selectedQuantity;
        break;
      case 2: // semanas
        totalDays = _selectedQuantity * 7;
        break;
      case 3: // meses
        totalDays = _selectedQuantity * 30;
        break;
      case 4: // anos
        totalDays = _selectedQuantity * 365;
        break;
    }

    setState(() {
      _showMaxYearWarning = totalDays > 365;
    });

    if (_showMaxYearWarning) {
      setState(() {
        _summary =
            '${loc?.translate('summary') ?? 'Resumen'}: ${loc?.translate('max_time_exceeded_summary') ?? 'Tiempo máximo excedido'}';
        return;
      });
    }

    final years = totalDays ~/ 365;
    final remainingDays = totalDays % 365;
    final months = remainingDays ~/ 30;
    final remainingDays2 = remainingDays % 30;
    final weeks = remainingDays2 ~/ 7;
    final days = remainingDays2 % 7;

    final parts = <String>[];
    if (years > 0)
      parts.add(
          '$years ${years == 1 ? (loc?.translate('year') ?? 'año') : (loc?.translate('years') ?? 'años')}');
    if (months > 0)
      parts.add(
          '$months ${months == 1 ? (loc?.translate('month') ?? 'mes') : (loc?.translate('months') ?? 'meses')}');
    if (weeks > 0)
      parts.add(
          '$weeks ${weeks == 1 ? (loc?.translate('week') ?? 'semana') : (loc?.translate('weeks') ?? 'semanas')}');
    if (days > 0)
      parts.add(
          '$days ${days == 1 ? (loc?.translate('day') ?? 'día') : (loc?.translate('days') ?? 'días')}');

    if (parts.isEmpty && totalDays > 0) {
      parts.add(
          '$totalDays ${totalDays == 1 ? (loc?.translate('day') ?? 'día') : (loc?.translate('days') ?? 'días')}');
    }

    setState(() {
      _summary =
          '${loc?.translate('summary') ?? 'Resumen'}: ${parts.isNotEmpty ? parts.join(' y ') : '0 ${loc?.translate('days') ?? 'días'}'}';
    });
  }

  void _roundBudgetOnUnfocus() {
    final value = _budgetController.text.trim();
    final numericValue = value.replaceAll(',', '');
    if (numericValue.isNotEmpty && double.tryParse(numericValue) != null) {
      final number = double.parse(numericValue);
      final roundedNumber = (number / 100).round() * 100;
      final formatted = roundedNumber.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );
      _budgetController.text = formatted;
      _validateBudget(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context);

    // Actualizar unidades según el idioma
    _updateUnitsForLanguage(context);

    // Agregar listener para redondear cuando el campo pierde el foco
    _budgetFocusNode.removeListener(_roundBudgetOnUnfocus);
    _budgetFocusNode.addListener(_roundBudgetOnUnfocus);
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
          loc?.translate('publish_your_need') ?? 'Publica lo que necesitas',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc?.translate('describe_need_phrase') ??
                  '¿Cómo describirías tu necesidad en una frase?',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(25.0),
                border: _titleError
                    ? Border.all(color: Colors.red, width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: _titleController,
                maxLines: null,
                minLines: 1,
                maxLength: 30,
                onChanged: _validateTitle,
                style: TextStyle(fontSize: 16, color: themeProvider.textColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  counterText: '',
                  hintText: _titleError
                      ? loc?.translate('min_3_words') ??
                          'Mínimo 3 palabras para mayor claridad'
                      : loc?.translate('describe_need_placeholder') ??
                          'Describe en al menos 3 palabras tu necesidad',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: _titleError
                        ? Colors.red[400]
                        : themeProvider.secondaryTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc?.translate('how_long_service') ??
                  '¿Cuánto tiempo crees que tomará completar este servicio?',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 100,
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
                    child: ListWheelScrollView.useDelegate(
                      controller: _quantityController,
                      itemExtent: 40,
                      diameterRatio: 2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedQuantity = (index % 100) + 1;
                          _updateSummary();
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 10000,
                        builder: (context, index) {
                          final actualValue = (index % 100) + 1;
                          final distance =
                              (index - _quantityController.selectedItem).abs() %
                                  100;
                          final isSelected = distance == 0;
                          final fontSize = isSelected ? 28 : 20;
                          final color = isSelected
                              ? themeProvider.textColor
                              : themeProvider.secondaryTextColor
                                  .withOpacity(0.6);
                          final fontWeight =
                              isSelected ? FontWeight.bold : FontWeight.normal;

                          return Center(
                            child: Text(
                              actualValue.toString(),
                              style: TextStyle(
                                fontSize: fontSize.toDouble(),
                                fontWeight: fontWeight,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 100,
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
                    child: ListWheelScrollView.useDelegate(
                      controller: _unitController,
                      itemExtent: 40,
                      diameterRatio: 2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedUnitIndex = index % _units.length;
                          _updateSummary();
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 10000,
                        builder: (context, index) {
                          final actualIndex = index % _units.length;
                          final unit = _selectedQuantity == 1
                              ? _unitsSingular[actualIndex]
                              : _units[actualIndex];
                          final distance =
                              (index - _unitController.selectedItem).abs() %
                                  _units.length;
                          final isSelected = distance == 0;
                          final fontSize = isSelected ? 20 : 16;
                          final color = isSelected
                              ? themeProvider.textColor
                              : themeProvider.secondaryTextColor
                                  .withOpacity(0.6);
                          final fontWeight =
                              isSelected ? FontWeight.bold : FontWeight.normal;

                          return Center(
                            child: Text(
                              unit,
                              style: TextStyle(
                                fontSize: fontSize.toDouble(),
                                fontWeight: fontWeight,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _showMaxYearWarning
                    ? Colors.red[50]
                    : themeProvider.isDarkMode
                        ? themeProvider.cardBgColor
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(10.0),
                border: _showMaxYearWarning
                    ? Border.all(color: Colors.red.withOpacity(0.5))
                    : null,
              ),
              child: Center(
                child: Text(
                  _showMaxYearWarning
                      ? loc?.translate('max_time_exceeded') ??
                          '⚠️ Tiempo máximo excedido (1 año)'
                      : _summary,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _showMaxYearWarning
                        ? Colors.red
                        : themeProvider.textColor,
                    fontWeight: _showMaxYearWarning
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc?.translate('how_much_pay') ??
                  '¿Cuánto estás dispuesto a pagar por este servicio?',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? themeProvider.cardBgColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(25.0),
                border: (_budgetError || _budgetMaxError)
                    ? Border.all(color: Colors.red, width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: _budgetController,
                focusNode: _budgetFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: TextStyle(fontSize: 16, color: themeProvider.textColor),
                onChanged: (value) {
                  // Validar que sea mínimo 5.000 y máximo 100.000.000
                  _validateBudget(value);

                  // Formatear el valor con separadores de miles (sin redondear mientras escribe)
                  final numericValue =
                      value.replaceAll('.', '').replaceAll(',', '');
                  if (numericValue.isNotEmpty &&
                      double.tryParse(numericValue) != null) {
                    final number = double.parse(numericValue);
                    final formatted =
                        number.toStringAsFixed(0).replaceAllMapped(
                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                              (match) => '${match[1]},',
                            );
                    _budgetController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
                onSubmitted: (value) {
                  // Redondear a centenas al salir del campo
                  final numericValue =
                      value.replaceAll('.', '').replaceAll(',', '');
                  if (numericValue.isNotEmpty &&
                      double.tryParse(numericValue) != null) {
                    final number = double.parse(numericValue);
                    final roundedNumber = (number / 100).round() * 100;
                    final formatted =
                        roundedNumber.toStringAsFixed(0).replaceAllMapped(
                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                              (match) => '${match[1]},',
                            );
                    _budgetController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                    _validateBudget(formatted);
                  }

                  if (_budgetMaxError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc?.translate('max_budget_error') ??
                            'El presupuesto máximo es de \$100.000.000 pesos'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (_budgetError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc?.translate('min_budget_error') ??
                            'El presupuesto mínimo es de \$5.000 pesos'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  hintText: _budgetError
                      ? loc?.translate('min_budget') ??
                          'El mínimo es \$5.000 pesos'
                      : _budgetMaxError
                          ? loc?.translate('max_budget') ??
                              'El máximo es \$100.000.000 pesos'
                          : loc?.translate('enter_budget') ??
                              'Ingresa el presupuesto',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: (_budgetError || _budgetMaxError)
                        ? Colors.red[400]
                        : themeProvider.secondaryTextColor,
                  ),
                  suffixText: 'COP',
                  suffixStyle: TextStyle(
                    fontSize: 16,
                    color: (_budgetError || _budgetMaxError)
                        ? Colors.red[400]
                        : themeProvider.secondaryTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc?.translate('describe_better') ??
                  'Describe mejor lo que necesitas',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(25.0),
                border: _descriptionError
                    ? Border.all(color: Colors.red, width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: null,
                minLines: 3,
                maxLength: 200,
                onChanged: _validateDescription,
                style: TextStyle(fontSize: 16, color: themeProvider.textColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  counterText: '',
                  hintText: _descriptionError
                      ? loc?.translate('min_20_words') ??
                          'Describe con más detalle (mínimo 20 palabras)'
                      : loc?.translate('describe_better_placeholder') ??
                          'Describe con detalle lo que necesitas (mínimo 20 palabras)',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: _descriptionError
                        ? Colors.red[400]
                        : themeProvider.secondaryTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc?.translate('worker_know_before') ??
                  '¿Hay algo que el trabajador deba saber antes de postularse?',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: TextField(
                controller: _workerInfoController,
                maxLines: null,
                minLines: 2,
                maxLength: 100,
                style: TextStyle(fontSize: 16, color: themeProvider.textColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  counterText: '',
                  hintText: loc?.translate('additional_info_worker') ??
                      'Información adicional para el trabajador',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: themeProvider.secondaryTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _publishService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF78BF32),
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
                  loc?.translate('publish_btn') ?? 'Publicar',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
