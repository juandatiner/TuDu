import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/service_in_search.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';
import 'all_services_screen.dart';
import 'service_detail_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class UserServicesScreen extends StatefulWidget {
  final String userEmail;

  const UserServicesScreen({super.key, required this.userEmail});

  @override
  State<UserServicesScreen> createState() => _UserServicesScreenState();
}

class _UserServicesScreenState extends State<UserServicesScreen>
    with SingleTickerProviderStateMixin {
  List<ServiceInSearch> _userServices = [];
  List<ServiceInSearch> _filteredServices = [];
  bool _isLoading = true;
  List<Service> _services = [];

  // Filtros
  String? _selectedStatusFilter;
  String _sortOrder = 'newest'; // 'newest' o 'oldest'
  bool _filtersExpanded = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Navegación
  int _selectedIndex = 2; // Servicios es el índice 2

  // Animación
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // Lista de estados disponibles con sus colores naturales
  final List<Map<String, dynamic>> _statusFilters = [
    {'status': 'EN ESPERA', 'color': Colors.grey, 'icon': Icons.schedule},
    {'status': 'EN PROCESO', 'color': Colors.amber, 'icon': Icons.autorenew},
    {'status': 'TERMINADO', 'color': Colors.green, 'icon': Icons.check_circle},
    {'status': 'CANCELADO', 'color': Colors.red, 'icon': Icons.cancel},
    {'status': 'RETRASADO', 'color': Colors.orange, 'icon': Icons.warning},
    {'status': 'FINALIZADO', 'color': Colors.brown, 'icon': Icons.done_all},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fetchUserServices();
    _fetchAllServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserServices() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.baseUrl}/services-in-search?user_email=${widget.userEmail}',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servicesJson = data['services_in_search'];
        setState(() {
          _userServices = servicesJson
              .map((json) => ServiceInSearch.fromJson(json))
              .toList();
          _isLoading = false;
          _applyFilters();
        });
      } else {
        print('Error fetching user services: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllServices() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/services'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servicesJson = data['services'];
        setState(() {
          _services =
              servicesJson.map((json) => Service.fromJson(json)).toList();
        });
      } else {
        print('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _applyFilters() {
    List<ServiceInSearch> result = List.from(_userServices);

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query);
      }).toList();
    }

    // Filtrar por estado
    if (_selectedStatusFilter != null) {
      result = result.where((s) => s.status == _selectedStatusFilter).toList();
    }

    // Ordenar por fecha
    result.sort((a, b) {
      DateTime dateA = DateTime.parse(a.createdAt);
      DateTime dateB = DateTime.parse(b.createdAt);
      return _sortOrder == 'newest'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    setState(() {
      _filteredServices = result;
    });
  }

  Widget _getStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'EN ESPERA':
        color = Colors.grey;
        icon = Icons.schedule;
        break;
      case 'EN PROCESO':
        color = Colors.amber;
        icon = Icons.autorenew;
        break;
      case 'TERMINADO':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'CANCELADO':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'RETRASADO':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'FINALIZADO':
        color = Colors.brown;
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeUnit(int quantity, String unit) {
    // Mapa de unidades en plural a singular
    final singularUnits = {
      'años': 'año',
      'meses': 'mes',
      'semanas': 'semana',
      'días': 'día',
      'horas': 'hora',
      'año': 'año',
      'mes': 'mes',
      'semana': 'semana',
      'día': 'día',
      'hora': 'hora',
    };

    final singularUnit = singularUnits[unit.toLowerCase()] ?? unit;
    if (quantity == 1) {
      return singularUnit;
    }
    // Casos especiales para plurales
    if (singularUnit == 'mes') return 'meses';
    return '${singularUnit}s';
  }

  void _showServiceDetails(ServiceInSearch service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(service: service),
      ),
    );
  }

  void _toggleFilters() {
    setState(() {
      if (_isSearching) {
        // Si estamos buscando, cambiar a filtros
        _isSearching = false;
        _searchController.clear();
        _searchQuery = '';
        _filtersExpanded = true;
        _animationController.forward();
      } else if (_filtersExpanded) {
        // Si filtros está expandido, colapsarlo
        _filtersExpanded = false;
        _animationController.reverse();
      } else {
        // Si nada está activo, expandir filtros
        _filtersExpanded = true;
        _animationController.forward();
      }
      _applyFilters();
    });
  }

  void _toggleSearch() {
    setState(() {
      if (_filtersExpanded) {
        // Si filtros está expandido, cambiar a búsqueda
        _filtersExpanded = false;
        _animationController.reverse();
        _isSearching = true;
      } else if (_isSearching) {
        // Si estamos buscando, cerrar búsqueda
        _isSearching = false;
        _searchController.clear();
        _searchQuery = '';
      } else {
        // Si nada está activo, abrir búsqueda
        _isSearching = true;
      }
      _applyFilters();
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      // Inicio
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              HomeScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else if (index == 1) {
      // Mensajes - por implementar
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 2) {
      // Servicios - ya estamos aquí
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 3) {
      // Perfil
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProfileScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Mis Servicios',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
      ),
      body: Container(
        color: themeProvider.scaffoldBgColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BARRA SUPERIOR FIJA (botones de filtros)
              Container(
                color: themeProvider.scaffoldBgColor,
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                child: Column(
                  children: [
                    // Fila con filtros/barra de búsqueda y botones
                    Row(
                      children: [
                        // Botón de FILTROS siempre visible
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _filtersExpanded
                                  ? [
                                      const Color(0xFF5A9A28),
                                      const Color(0xFF4A8A1A)
                                    ]
                                  : [
                                      const Color(0xFF78BF32),
                                      const Color(0xFF5A9A28)
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF78BF32)
                                    .withOpacity(_filtersExpanded ? 0.6 : 0.4),
                                blurRadius: _filtersExpanded ? 12 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleFilters,
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return RotationTransition(
                                      turns: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _filtersExpanded ? Icons.close : Icons.tune,
                                    color: Colors.white,
                                    size: 24,
                                    key: ValueKey(_filtersExpanded
                                        ? 'close_filter'
                                        : 'filter'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Contenido central (barra de búsqueda o contador)
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: _isSearching
                                ? // BARRA DE BÚSQUEDA
                                Container(
                                    key: const ValueKey('search_bar'),
                                    decoration: BoxDecoration(
                                      color: themeProvider.cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: themeProvider.isDarkMode
                                              ? Colors.black.withOpacity(0.3)
                                              : const Color(0xFF78BF32)
                                                  .withOpacity(0.2),
                                          spreadRadius: 2,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 16),
                                          child: const Icon(
                                            Icons.search,
                                            color: Color(0xFF78BF32),
                                            size: 22,
                                          ),
                                        ),
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Ajustar tamaño de fuente basado en el ancho disponible
                                              // El texto siempre será "¿Qué servicio buscas?"
                                              double fontSize;

                                              if (constraints.maxWidth < 100) {
                                                fontSize = 9.0;
                                              } else if (constraints.maxWidth <
                                                  130) {
                                                fontSize = 10.0;
                                              } else if (constraints.maxWidth <
                                                  160) {
                                                fontSize = 11.0;
                                              } else if (constraints.maxWidth <
                                                  200) {
                                                fontSize = 12.0;
                                              } else if (constraints.maxWidth <
                                                  240) {
                                                fontSize = 13.0;
                                              } else {
                                                fontSize = 14.0;
                                              }

                                              return TextField(
                                                controller: _searchController,
                                                autofocus: true,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _searchQuery = value;
                                                    _applyFilters();
                                                  });
                                                },
                                                decoration: InputDecoration(
                                                  hintText:
                                                      '¿Qué servicio buscas?',
                                                  hintStyle: TextStyle(
                                                    color: themeProvider
                                                        .secondaryTextColor,
                                                    fontSize: fontSize,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 6,
                                                    vertical: 14,
                                                  ),
                                                  isDense: true,
                                                ),
                                                style: TextStyle(
                                                  fontSize: fontSize,
                                                  color:
                                                      themeProvider.textColor,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // Contador
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF78BF32),
                                                Color(0xFF5A9A28)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Text(
                                            '${_filteredServices.length}/${_userServices.length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (_searchQuery.isNotEmpty)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(right: 4),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _searchController.clear();
                                                    _searchQuery = '';
                                                    _applyFilters();
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Icon(
                                                    Icons.refresh,
                                                    color: themeProvider
                                                        .secondaryTextColor,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : // CONTADOR DE SERVICIOS
                                Container(
                                    key: const ValueKey('counter'),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: themeProvider.cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: themeProvider.isDarkMode
                                              ? Colors.black.withOpacity(0.3)
                                              : const Color(0xFF78BF32)
                                                  .withOpacity(0.15),
                                          spreadRadius: 2,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.list_alt,
                                          color:
                                              themeProvider.secondaryTextColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_filteredServices.length} de ${_userServices.length} servicios',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón de LUPA siempre visible
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isSearching
                                  ? [
                                      const Color(0xFF5A9A28),
                                      const Color(0xFF4A8A1A)
                                    ]
                                  : [
                                      const Color(0xFF78BF32),
                                      const Color(0xFF5A9A28)
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF78BF32)
                                    .withOpacity(_isSearching ? 0.6 : 0.4),
                                blurRadius: _isSearching ? 12 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleSearch,
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return RotationTransition(
                                      turns: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _isSearching ? Icons.close : Icons.search,
                                    color: Colors.white,
                                    size: 24,
                                    key: ValueKey(_isSearching
                                        ? 'close_search'
                                        : 'search'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Panel de filtros desplegable (debajo de los botones)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: _filtersExpanded
                          ? Container(
                              margin: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: themeProvider.isDarkMode
                                      ? [
                                          themeProvider.cardBgColor,
                                          const Color(0xFF252527)
                                        ]
                                      : [Colors.white, Colors.grey[50]!],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: themeProvider.isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : const Color(0xFF78BF32)
                                            .withOpacity(0.15),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Filtro por estado
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.info_outline,
                                            color: Colors.blue,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Estado:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: themeProvider.textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildAnimatedChip(
                                          label: 'Todos',
                                          icon: Icons.select_all,
                                          isSelected:
                                              _selectedStatusFilter == null,
                                          selectedColor: const Color(
                                              0xFF42A5F5), // Azul oscuro no tan oscuro
                                          onTap: () {
                                            setState(() {
                                              _selectedStatusFilter = null;
                                              _applyFilters();
                                            });
                                          },
                                        ),
                                        ..._statusFilters.map((filter) {
                                          return _buildAnimatedChip(
                                            label: filter['status'],
                                            icon: filter['icon'],
                                            isSelected: _selectedStatusFilter ==
                                                filter['status'],
                                            selectedColor: filter['color'],
                                            onTap: () {
                                              setState(() {
                                                _selectedStatusFilter =
                                                    filter['status'];
                                                _applyFilters();
                                              });
                                            },
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    // Filtro por orden
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.purple.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.sort,
                                            color: Colors.purple,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ordenar por:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: themeProvider.textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _buildAnimatedChip(
                                          label: 'Más reciente',
                                          icon: Icons.arrow_downward,
                                          iconColor: const Color(
                                              0xFFE91E63), // Flecha rosa
                                          isSelected: _sortOrder == 'newest',
                                          selectedColor: const Color(
                                              0xFFF8BBD9), // Rosa pastel
                                          onTap: () {
                                            setState(() {
                                              _sortOrder = 'newest';
                                              _applyFilters();
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _buildAnimatedChip(
                                          label: 'Más antiguo',
                                          icon: Icons.arrow_upward,
                                          iconColor: const Color(
                                              0xFF00838F), // Flecha agua marina oscuro
                                          isSelected: _sortOrder == 'oldest',
                                          selectedColor: const Color(
                                              0xFF80DEEA), // Azul agua marina pastel
                                          onTap: () {
                                            setState(() {
                                              _sortOrder = 'oldest';
                                              _applyFilters();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // CONTENIDO SCROLLEABLE (lista de servicios)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _userServices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: themeProvider.secondaryTextColor,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No tienes servicios asignados',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Busca o publica que necesitas',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: themeProvider.secondaryTextColor),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AllServicesScreen(
                                          services: _services,
                                          userEmail: widget.userEmail,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF78BF32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    'Buscar Servicios',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredServices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: themeProvider.isDarkMode
                                            ? const Color(0xFF3A3A3C)
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.filter_list_off,
                                        size: 50,
                                        color: themeProvider.secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No se encontraron resultados para "$_searchQuery"'
                                          : 'No hay servicios con estos filtros',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: themeProvider.secondaryTextColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedStatusFilter = null;
                                          _searchQuery = '';
                                          _searchController.clear();
                                          _applyFilters();
                                        });
                                      },
                                      icon: const Icon(Icons.refresh,
                                          color: Color(0xFF78BF32)),
                                      label: const Text(
                                        'Limpiar filtros',
                                        style: TextStyle(
                                          color: Color(0xFF78BF32),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16.0, 0, 16.0, 16.0),
                                itemCount: _filteredServices.length,
                                itemBuilder: (context, index) {
                                  final service = _filteredServices[index];
                                  return GestureDetector(
                                    onTap: () => _showServiceDetails(service),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: themeProvider.cardBgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: themeProvider.shadowColor,
                                            spreadRadius: 1,
                                            blurRadius: 5,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors:
                                                      themeProvider.isDarkMode
                                                          ? [
                                                              const Color(
                                                                  0xFF3A3A3C),
                                                              const Color(
                                                                  0xFF2C2C2E)
                                                            ]
                                                          : [
                                                              Colors.grey[200]!,
                                                              Colors.grey[100]!
                                                            ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.work_outline,
                                                  color: themeProvider
                                                      .secondaryTextColor,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          service.title,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: themeProvider
                                                                .textColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      _getStatusBadge(
                                                          service.status),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    service.description,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: themeProvider
                                                          .secondaryTextColor,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: themeProvider
                                                                .secondaryTextColor,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            '${service.timeQuantity} ${_formatTimeUnit(service.timeQuantity, service.timeUnit)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: themeProvider
                                                                  .secondaryTextColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .calendar_today,
                                                            size: 14,
                                                            color: themeProvider
                                                                .secondaryTextColor,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            '${service.createdAt.substring(0, 10)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: themeProvider
                                                                  .secondaryTextColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              // Espacio gris inferior antes de la barra de navegación
              Container(
                height: 16,
                color: themeProvider.scaffoldBgColor,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Servicios'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor:
            themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: themeProvider.cardBgColor,
        elevation: 10,
      ),
    );
  }

  Widget _buildAnimatedChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Si hay un color de icono personalizado, usarlo; si no, el color normal
    final effectiveIconColor = iconColor ??
        (isSelected ? Colors.white : themeProvider.secondaryTextColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        selectedColor,
                        selectedColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : (themeProvider.isDarkMode
                      ? const Color(0xFF3A3A3C)
                      : Colors.grey[200]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: selectedColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: effectiveIconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : themeProvider.textColor,
                    fontSize: 12,
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
