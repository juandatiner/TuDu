import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';
import 'all_services_screen.dart';
import 'allies_by_service_screen.dart';
import 'publish_service_screen.dart';
import 'user_services_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;

  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _suggestionsController = PageController();
  final PageController _newServicesController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _suggestionsCurrentPage = 0;
  int _newServicesCurrentPage = 0;
  int _selectedIndex = 0;
  List<Service> _services = [];
  List<Service> _suggestedServices = [];
  List<Service> _newServices = [];

  @override
  void initState() {
    super.initState();
    _suggestionsController.addListener(() {
      setState(() {
        _suggestionsCurrentPage = _suggestionsController.page!.round();
      });
    });
    _newServicesController.addListener(() {
      setState(() {
        _newServicesCurrentPage = _newServicesController.page!.round();
      });
    });
    _fetchServices();
    _initializeTheme();
  }

  /// Inicializa el tema del usuario desde el backend
  void _initializeTheme() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.initializeWithUser(widget.userEmail);
    });
  }

  @override
  void dispose() {
    _suggestionsController.dispose();
    _newServicesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    // Navegación para el botón de Servicios
    if (index == 2) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              UserServicesScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      // Al volver de Servicios, restablecer el índice a Inicio
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
    // Navegación para el botón de Perfil
    if (index == 3) {
      await Navigator.push(
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
      // Al volver de Perfil, restablecer el índice a Inicio
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
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

  Future<void> _fetchServices() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/services'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> servicesJson = data['services'];
        setState(() {
          _services =
              servicesJson.map((json) => Service.fromJson(json)).toList();
          _newServices = _services.length > 5
              ? _services.sublist(_services.length - 5)
              : _services;
          _suggestedServices = List.from(_services)
            ..shuffle()
            ..take(5).toList();
        });
      } else {
        // Manejar error
        print('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de búsqueda con autocompletado
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SearchScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                  child: Container(
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
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: '¿Qué servicio necesitas hoy?',
                        hintStyle:
                            TextStyle(color: themeProvider.secondaryTextColor),
                        prefixIcon: Icon(Icons.search,
                            color: themeProvider.secondaryTextColor),
                        suffixIcon: Icon(Icons.mic,
                            color: themeProvider.secondaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sección Sugerencias
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          'Sugerencias',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ],
                    ),
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
                        backgroundColor: themeProvider.isDarkMode
                            ? themeProvider.cardBgColor
                            : const Color(0xFFE7E7E7),
                        foregroundColor: themeProvider.textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Explorar más servicios'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Carrusel Sugerencias
                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: _suggestionsController,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final service = index < _suggestedServices.length
                          ? _suggestedServices[index]
                          : null;
                      return GestureDetector(
                        onTap: () {
                          if (service != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AlliesByServiceScreen(service: service),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: themeProvider.cardBgColor,
                            borderRadius: BorderRadius.circular(10),
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
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.blue, // Placeholder
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service?.name ?? 'Servicio de hogar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Indicadores de página para Sugerencias
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _suggestionsCurrentPage == index
                            ? Colors.blue
                            : themeProvider.secondaryTextColor,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),
                // Sección Nuevos Servicios
                Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Nuevos Servicios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Carrusel Nuevos Servicios
                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: _newServicesController,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final service = index < _newServices.length
                          ? _newServices[index]
                          : null;
                      return GestureDetector(
                        onTap: () {
                          if (service != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AlliesByServiceScreen(service: service),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: themeProvider.cardBgColor,
                            borderRadius: BorderRadius.circular(10),
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
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.green, // Placeholder
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service?.name ?? 'Servicio de hogar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Indicadores de página para Nuevos Servicios
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _newServicesCurrentPage == index
                            ? Colors.green
                            : themeProvider.secondaryTextColor,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),
                // Sección "¿No encuentras lo que buscas?"
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? themeProvider.cardBgColor
                        : const Color(0xFFE7E7E7),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.shadowColor,
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '¿No encuentras lo que buscas?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
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
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.message), label: 'Mensajes'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.work), label: 'Servicios'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Perfil'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue,
            unselectedItemColor: themeProvider.secondaryTextColor,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: themeProvider.cardBgColor,
            elevation: 10,
          );
        },
      ),
    );
  }
}
