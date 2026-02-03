import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class PublishServiceScreen extends StatefulWidget {
  final String userEmail;

  const PublishServiceScreen({super.key, required this.userEmail});

  @override
  State<PublishServiceScreen> createState() => _PublishServiceScreenState();
}

class _PublishServiceScreenState extends State<PublishServiceScreen> {
  int _selectedQuantity = 1;
  int _selectedUnitIndex = 0;
  String _summary = 'Resumen: 0 días';
  bool _showMaxYearWarning = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _workerInfoController = TextEditingController();
  final TextEditingController _additionalInfoController =
      TextEditingController();

  final List<String> _units = ['Horas', 'Días', 'Semanas', 'Meses', 'Años'];
  final FixedExtentScrollController _quantityController =
      FixedExtentScrollController(initialItem: 5000);
  final FixedExtentScrollController _unitController =
      FixedExtentScrollController(initialItem: 5000);

  Future<void> _publishService() async {
    // Verificar que todos los campos estén llenos (sin solo espacios en blanco)
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final budget = _budgetController.text.trim();
    final workerInfo = _workerInfoController.text.trim();
    final additionalInfo = _additionalInfoController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        budget.isEmpty ||
        workerInfo.isEmpty ||
        additionalInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los campos son obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Eliminar separadores de miles antes de enviar al backend
    final numericBudget = budget.replaceAll(',', '');

    final url = Uri.parse('${Config.baseUrl}/publish-service');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': widget.userEmail,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'time_quantity': _selectedQuantity,
          'time_unit': _units[_selectedUnitIndex].toLowerCase(),
          'budget': numericBudget,
          'worker_info': _workerInfoController.text,
          'additional_info': _additionalInfoController.text,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio publicado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al publicar el servicio: ${response.statusCode} - ${response.body}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
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
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _updateSummary() {
    if (_selectedQuantity == 0) {
      setState(() {
        _summary = 'Resumen: 0 días';
        _showMaxYearWarning = false;
      });
      return;
    }

    int totalDays = 0;
    switch (_selectedUnitIndex) {
      case 0: // horas
        totalDays = (_selectedQuantity / 24).ceil();
        break;
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
        _summary = 'Resumen: Tiempo máximo excedido';
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
    if (years > 0) parts.add('$years año${years > 1 ? 's' : ''}');
    if (months > 0) parts.add('$months mes${months > 1 ? 'es' : ''}');
    if (weeks > 0) parts.add('$weeks semana${weeks > 1 ? 's' : ''}');
    if (days > 0) parts.add('$days día${days > 1 ? 's' : ''}');

    if (parts.isEmpty && totalDays > 0) {
      parts.add('$totalDays día${totalDays > 1 ? 's' : ''}');
    }

    setState(() {
      _summary = 'Resumen: ${parts.isNotEmpty ? parts.join(' y ') : '0 días'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF4F2F2),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Publica lo que necesitas',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 30),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Cómo describirías tu necesidad en una frase?',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '¿Cuánto tiempo crees que tomará completar este servicio?',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
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
                                      (index - _quantityController.selectedItem)
                                          .abs() %
                                      100;
                                  final isSelected = distance == 0;
                                  final fontSize = isSelected ? 28 : 20;
                                  final color = isSelected
                                      ? Colors.black
                                      : Colors.grey.withOpacity(0.6);
                                  final fontWeight = isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal;

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
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
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
                                  final unit = _units[actualIndex];
                                  final distance =
                                      (index - _unitController.selectedItem)
                                          .abs() %
                                      _units.length;
                                  final isSelected = distance == 0;
                                  final fontSize = isSelected ? 20 : 16;
                                  final color = isSelected
                                      ? Colors.black
                                      : Colors.grey.withOpacity(0.6);
                                  final fontWeight = isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal;

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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: _showMaxYearWarning
                            ? Colors.red[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10.0),
                        border: _showMaxYearWarning
                            ? Border.all(color: Colors.red.withOpacity(0.5))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          _showMaxYearWarning
                              ? '⚠️ Tiempo máximo excedido (1 año)'
                              : _summary,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _showMaxYearWarning
                                ? Colors.red
                                : Colors.black,
                            fontWeight: _showMaxYearWarning
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '¿Cuánto estás dispuesto a pagar por este servicio?',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          // Formatear el valor con separadores de miles
                          final numericValue = value
                              .replaceAll('.', '')
                              .replaceAll(',', '');
                          if (numericValue.isNotEmpty &&
                              double.tryParse(numericValue) != null) {
                            final number = double.parse(numericValue);
                            final formatted = number
                                .toStringAsFixed(0)
                                .replaceAllMapped(
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
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          hintText: 'Ingresa el presupuesto',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Describe mejor lo que necesitas',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '¿Hay algo que el trabajador deba saber antes de postularse?',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _workerInfoController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Observaciones adicionales',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _additionalInfoController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

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
                        child: const Text(
                          'Publicar',
                          style: TextStyle(
                            fontSize: 18,
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
}
