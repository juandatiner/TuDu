import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config.dart';
import '../models/service.dart';
import 'allies_by_service_screen.dart';
import 'all_services_screen.dart';

class SearchScreen extends StatefulWidget {
  final String userEmail;

  const SearchScreen({super.key, required this.userEmail});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Service> _searchResults = [];
  List<Service> _filteredServices = [];
  List<dynamic> _searchHistory = [];
  List<Service> _randomServices = [];
  List<Service> _allServices = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    print('SearchScreen initialized with userEmail: ${widget.userEmail}');
    _fetchAllServices();
    _fetchSearchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      setState(() {
        _showSuggestions = true;
        _filterServices(query);
      });
    } else {
      setState(() {
        _showSuggestions = false;
        _filteredServices = [];
      });
    }
  }

  void _filterServices(String query) {
    final normalizedQuery = _removeDiacritics(query.toLowerCase());
    setState(() {
      _filteredServices = _allServices.where((service) {
        final normalizedName = _removeDiacritics(service.name.toLowerCase());
        return normalizedName.contains(normalizedQuery);
      }).toList();
    });
  }

  Future<void> _fetchAllServices() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/services'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servicesJson = data['services'];
        setState(() {
          _allServices =
              servicesJson.map((json) => Service.fromJson(json)).toList();
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
      final encodedEmail = Uri.encodeComponent(widget.userEmail);
      final url = '${Config.baseUrl}/search-history?user_email=$encodedEmail';
      print('Fetching search history from: $url');
      print('User email: ${widget.userEmail}');

      final response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Search history data: $data');
        setState(() {
          _searchHistory = data['search_history'] ?? [];
        });
        print('Search history loaded: ${_searchHistory.length} items');
      } else {
        print('Error fetching search history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching search history: $e');
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

    setState(() {
      _isSearching = true;
    });

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
          _searchResults =
              data['services'].map((json) => Service.fromJson(json)).toList();
          _isSearching = false;
        });
      } else {
        print('Error searching services: ${response.statusCode}');
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    try {
      print('Saving search query: $query for user: ${widget.userEmail}');
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/search-history'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': widget.userEmail,
          'search_query': query,
        }),
      );
      print('Save search response: ${response.statusCode} - ${response.body}');
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

  void _navigateToService(Service service) async {
    _saveSearchQuery(service.name);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlliesByServiceScreen(service: service),
      ),
    );
    // Limpiar el buscador y actualizar historial al volver
    _searchController.clear();
    _fetchSearchHistory();
  }

  void _navigateToSearchResults(String query) async {
    if (query.isEmpty) return;

    _saveSearchQuery(query);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllServicesScreen(
          services: _allServices,
          initialSearchQuery: query,
          userEmail: widget.userEmail,
          title: 'Resultados',
        ),
      ),
    );
    // Limpiar el buscador y actualizar historial al volver
    _searchController.clear();
    _fetchSearchHistory();
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
            focusNode: _focusNode,
            autofocus: true,
            enabled: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _navigateToSearchResults(value);
              }
            },
            decoration: const InputDecoration(
              hintText: 'Servicios de...',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Si está escribiendo y hay texto
    if (_searchController.text.isNotEmpty) {
      // Si hay sugerencias que coinciden
      if (_filteredServices.isNotEmpty) {
        return _buildSuggestionsList();
      } else {
        // Si nada coincide, mostrar botón con imagen difuminada
        return _buildNoResultsView();
      }
    }

    // Vista normal cuando no hay búsqueda activa
    return _buildNormalView();
  }

  Widget _buildSuggestionsList() {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        itemCount: _filteredServices.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, index) {
          final service = _filteredServices[index];
          return ListTile(
            leading: const Icon(Icons.search, color: Colors.grey),
            title: Text(
              service.name,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            onTap: () {
              _navigateToService(service);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Stack(
      children: [
        // Imagen de fondo difuminada
        Positioned.fill(
          child: Image.asset(
            'assets/icons/icono.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.grey[300]);
            },
          ),
        ),
        // Capa difuminada
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.85)),
        ),
        // Contenido central
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón circular con imagen
              GestureDetector(
                onTap: () {
                  _navigateToSearchResults(_searchController.text);
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/icono.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF78BF32),
                          child: const Icon(
                            Icons.search,
                            size: 50,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No se encontraron resultados para',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 5),
              Text(
                '"${_searchController.text}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  _navigateToSearchResults(_searchController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF78BF32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Buscar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalView() {
    return Column(
      children: [
        // Parte fija superior (servicios aleatorios y últimos servicios)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Servicios aleatorios
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _randomServices.length,
                  itemBuilder: (context, index) {
                    final service = _randomServices[index];
                    return GestureDetector(
                      onTap: () {
                        _navigateToService(service);
                      },
                      child: Container(
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
              // Últimos servicios contratados
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
              // Línea separadora antes del historial
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
        // Parte con scroll solo para el historial
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del historial con diseño mejorado
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 85, 88, 220)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Color.fromARGB(255, 0, 24, 162),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Búsquedas Recientes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de historial
                Expanded(
                  child: _searchHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay búsquedas recientes',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tus búsquedas aparecerán aquí',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _searchHistory.length,
                          itemBuilder: (context, index) {
                            final item = _searchHistory[index];
                            print('Rendering history item: $item');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    _searchController.text =
                                        item['search_query'] ?? '';
                                    _navigateToSearchResults(
                                      item['search_query'] ?? '',
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF78BF32)
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.search,
                                            color: Color(0xFF78BF32),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            item['search_query'] ??
                                                'Sin título',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              onTap: () {
                                                _deleteSearchHistory(
                                                    item['id']);
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
