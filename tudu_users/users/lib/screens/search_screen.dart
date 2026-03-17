import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'allies_by_service_screen.dart';
import 'all_services_screen.dart';
import 'publish_service_screen.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.scaffoldBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Container(
          decoration: BoxDecoration(
            color: themeProvider.cardBgColor,
            borderRadius: BorderRadius.circular(25.0),
            boxShadow: [
              BoxShadow(
                color: themeProvider.isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF78BF32).withOpacity(0.15),
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
            decoration: InputDecoration(
              hintText: loc?.translate('services_of') ?? 'Servicios de...',
              hintStyle: TextStyle(color: themeProvider.secondaryTextColor),
              prefixIcon:
                  Icon(Icons.search, color: themeProvider.secondaryTextColor),
              suffixIcon:
                  Icon(Icons.mic, color: themeProvider.secondaryTextColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: themeProvider.textColor),
          ),
        ),
      ),
      body: _buildBody(themeProvider, loc),
      floatingActionButton: _searchController.text.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                final loc = AppLocalizations.of(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: themeProvider.cardBgColor,
                  builder: (BuildContext context) {
                    return Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            loc?.translate('cant_find_what_looking_for') ??
                                '¿No encuentras lo que buscas?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            loc?.translate('publish_request_experts') ??
                                'Publica tu solicitud y deja que los expertos vengan a ti. No pierdas tiempo buscando, ¡ellos te encontrarán!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.secondaryTextColor,
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
                                  builder: (context) => PublishServiceScreen(
                                    userEmail: widget.userEmail,
                                  ),
                                ),
                              );
                            },
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
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Icon(Icons.question_mark,
                  color: Color(0xFF78BF32), size: 36),
              backgroundColor: themeProvider.isDarkMode
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFFE7E7E7),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeProvider themeProvider, AppLocalizations? loc) {
    // Si está escribiendo y hay texto
    if (_searchController.text.isNotEmpty) {
      // Si hay sugerencias que coinciden
      if (_filteredServices.isNotEmpty) {
        return _buildSuggestionsList(themeProvider);
      } else {
        // Si nada coincide, mostrar botón con imagen difuminada
        return _buildNoResultsView(themeProvider, loc);
      }
    }

    // Vista normal cuando no hay búsqueda activa
    return _buildNormalView(themeProvider);
  }

  Widget _buildSuggestionsList(ThemeProvider themeProvider) {
    return Column(
      children: [
        // Espacio mínimo para que la sombra de la barra de búsqueda no se corte
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            color: themeProvider.cardBgColor,
            child: ListView.separated(
              itemCount: _filteredServices.length,
              separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: themeProvider.isDarkMode
                      ? Colors.grey[700]
                      : Colors.grey[300]),
              itemBuilder: (context, index) {
                final service = _filteredServices[index];
                return ListTile(
                  leading: Icon(Icons.search,
                      color: themeProvider.secondaryTextColor),
                  title: Text(
                    service.name,
                    style:
                        TextStyle(fontSize: 16, color: themeProvider.textColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  onTap: () {
                    _navigateToService(service);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsView(
      ThemeProvider themeProvider, AppLocalizations? loc) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Mensaje de no resultados
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardBgColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: themeProvider.isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 50,
                color: themeProvider.secondaryTextColor,
              ),
              const SizedBox(height: 12),
              Text(
                "${loc?.translate('no_results_for_query') ?? 'No encontramos resultados para'} '${_searchController.text}'",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                loc?.translate('try_different_search') ??
                    'Intenta buscando de otra manera',
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalView(ThemeProvider themeProvider) {
    return Column(
      children: [
        // Espacio mínimo para que la sombra de la barra de búsqueda no se corte
        const SizedBox(height: 6),
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
                          color: themeProvider.cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Línea separadora
              Container(
                height: 1,
                color: themeProvider.isDarkMode
                    ? Colors.grey[700]
                    : Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 6),
              ),
              // Últimos servicios contratados
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF1976D2),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Últimos servicios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Tamaño máximo y mínimo de cada círculo
                  const double maxCircleSize = 66.0;
                  const double minCircleSize = 50.0;
                  const double marginBetween = 10.0;

                  // Calcular cuántos círculos caben con el tamaño máximo
                  int maxCirclesThatFit =
                      ((constraints.maxWidth + marginBetween) /
                              (maxCircleSize + marginBetween))
                          .floor();
                  // Mínimo 4 círculos, máximo 10
                  int circleCount = max(4, min(maxCirclesThatFit, 10));

                  // Calcular el tamaño real de cada círculo para que quepan tudus centrados
                  double totalMarginSpace = (circleCount - 1) * marginBetween;
                  double availableWidthForCircles =
                      constraints.maxWidth - totalMarginSpace;
                  double calculatedSize =
                      availableWidthForCircles / circleCount;
                  // Limitar entre minCircleSize y maxCircleSize
                  double circleSize =
                      calculatedSize.clamp(minCircleSize, maxCircleSize);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(circleCount, (index) {
                      return Container(
                        margin: EdgeInsets.only(
                            right: index < circleCount - 1 ? marginBetween : 0),
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          color: themeProvider.cardBgColor,
                          borderRadius: BorderRadius.circular(circleSize / 2),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey,
                          ),
                        ),
                        child: const Center(),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Línea separadora antes del historial
              Container(
                height: 1,
                color: themeProvider.isDarkMode
                    ? Colors.grey[700]
                    : Colors.grey[300],
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
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 85, 88, 220)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.history,
                          color: themeProvider.isDarkMode
                              ? const Color(0xFFE91E63)
                              : const Color(0xFFE91E63),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Búsquedas Recientes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
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
                                color: themeProvider.secondaryTextColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay búsquedas recientes',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: themeProvider.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tus búsquedas aparecerán aquí',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          itemCount: _searchHistory.length,
                          itemBuilder: (context, index) {
                            final item = _searchHistory[index];
                            print('Rendering history item: $item');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: themeProvider.cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: themeProvider.isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.1),
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
                                      vertical: 10,
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
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item['search_query'] ??
                                                'Sin título',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: themeProvider.textColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey[700]
                                                : Colors.grey[100],
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
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: themeProvider
                                                      .secondaryTextColor,
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
