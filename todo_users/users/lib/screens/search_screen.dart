import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config.dart';
import '../models/service.dart';

class SearchScreen extends StatefulWidget {
  final String userEmail;

  const SearchScreen({super.key, required this.userEmail});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Service> _searchResults = [];
  List<dynamic> _searchHistory = [];
  List<Service> _randomServices = [];
  List<Service> _allServices = [];

  @override
  void initState() {
    super.initState();
    _fetchAllServices();
    _fetchSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllServices() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/services'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servicesJson = data['services'];
        setState(() {
          _allServices = servicesJson
              .map((json) => Service.fromJson(json))
              .toList();
          print('Total de servicios obtenidos: ${_allServices.length}');

          final shuffledServices = List.from(_allServices)..shuffle();
          _randomServices = shuffledServices.take(5).cast<Service>().toList();

          print('Servicios aleatorios a mostrar: ${_randomServices.length}');
          print(
            'Nombres de servicios aleatorios: ${_randomServices.map((s) => s.name).toList()}',
          );
        });
      } else {
        print('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _fetchSearchHistory() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.baseUrl}/search-history?user_email=${widget.userEmail}',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchHistory = data['search_history'];
        });
      } else {
        print('Error fetching search history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _searchServices(String query) async {
    print('Buscando: $query');
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final url = '${Config.baseUrl}/search-services?query=$query';
      print('URL de búsqueda: $url');
      final response = await http.get(Uri.parse(url));

      print('Estado de la respuesta: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Resultados: ${data['services']}');
        setState(() {
          _searchResults = data['services']
              .map((json) => Service.fromJson(json))
              .toList();
        });
      } else {
        print('Error searching services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    try {
      await http.post(
        Uri.parse('${Config.baseUrl}/search-history'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': widget.userEmail,
          'search_query': query,
        }),
      );
      _fetchSearchHistory();
    } catch (e) {
      print('Error saving search query: $e');
    }
  }

  Future<void> _deleteSearchHistory(int id) async {
    try {
      await http.delete(Uri.parse('${Config.baseUrl}/search-history/$id'));
      _fetchSearchHistory();
    } catch (e) {
      print('Error deleting search history: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F2F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Container(
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
            autofocus: true,
            enabled: true,
            onChanged: (value) {
              _searchServices(value);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _saveSearchQuery(value);
              }
            },
            decoration: const InputDecoration(
              hintText: 'Servicios..',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: Icon(Icons.mic, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resultados de búsqueda
              if (_searchController.text.isNotEmpty &&
                  _searchResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._searchResults.map((service) {
                      return ListTile(
                        title: Text(service.name),
                        onTap: () {
                          _saveSearchQuery(service.name);
                          // Navegar a la pantalla de aliados por servicio
                        },
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                ),

              // Servicios aleatorios
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _randomServices.length,
                      itemBuilder: (context, index) {
                        final service = _randomServices[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Center(
                            child: Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Línea separadora
                  Container(
                    height: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ],
              ),
              // Últimos servicios contratados
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Últimos servicios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Calcula el número de círculos que caben en la pantalla
                      // Tamaño del círculo + margen derecho (70px total por elemento)
                      int maxCircles = (constraints.maxWidth ~/ 70);
                      // Asegura un mínimo de 4 círculos (para celulares) y máximo razonable
                      int circleCount = max(4, min(maxCircles, 10));

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(circleCount, (index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 66, // 10% más grande que 60px
                            height: 66, // 10% más grande que 60px
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(33),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),

              // Búsquedas recientes
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Búsquedas Recientes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._searchHistory.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 1.0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item['search_query'],
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _deleteSearchHistory(item['id']);
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

