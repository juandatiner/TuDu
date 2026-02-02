import 'package:flutter/material.dart';
import '../models/service.dart';
import 'allies_by_service_screen.dart';
import 'publish_service_screen.dart';

class AllServicesScreen extends StatefulWidget {
  final List<Service> services;
  final String initialSearchQuery;

  const AllServicesScreen({
    super.key,
    required this.services,
    this.initialSearchQuery = '',
  });

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  late List<Service> _filteredServices;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredServices = widget.services;
    _searchController.addListener(_filterServices);
    // Establecer el query de búsqueda inicial si existe
    if (widget.initialSearchQuery.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery;
      // Ejecutar el filtrado manualmente ya que el listener no se activa al establecer el texto programáticamente
      _filterServices();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _removeDiacritics(String text) {
    const accentMap = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'ñ': 'n',
      'Ñ': 'n',
    };
    return text.split('').map((char) => accentMap[char] ?? char).join('');
  }

  void _filterServices() {
    final query = _removeDiacritics(_searchController.text.toLowerCase());
    setState(() {
      _filteredServices = widget.services
          .where(
            (service) =>
                _removeDiacritics(service.name.toLowerCase()).contains(query),
          )
          .toList();
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
                // Flecha atrás y título
                SizedBox(
                  height: 50,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.green,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Center(
                        child: Text(
                          'Todos los Servicios',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Barra de búsqueda
                Container(
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '¿Qué servicio necesitas hoy?',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.mic, color: Colors.grey),
                        onPressed: () {
                          // Funcionalidad de micrófono (placeholder)
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Grid de servicios
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _filteredServices.length,
                  itemBuilder: (context, index) {
                    final service = _filteredServices[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AlliesByServiceScreen(service: service),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
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
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blue, // Placeholder
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Imagen',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¿No encuentras lo que buscas?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Publica tu solicitud y deja que los expertos vengan a ti. No pierdas tiempo buscando, ¡ellos te encontrarán!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Cerrar el modal
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PublishServiceScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF78BF32,
                        ), // Verde #78BF32
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
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.question_mark, color: Colors.green, size: 36),
        backgroundColor: const Color(0xFFE7E7E7),
      ),
    );
  }
}
