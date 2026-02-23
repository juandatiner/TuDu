import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'allies_by_service_screen.dart';
import 'publish_service_screen.dart';

class AllServicesScreen extends StatefulWidget {
  final List<Service> services;
  final String initialSearchQuery;
  final String userEmail;
  final String title;

  const AllServicesScreen({
    super.key,
    required this.services,
    this.initialSearchQuery = '',
    required this.userEmail,
    this.title = 'Todos los Servicios',
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
    final themeProvider = Provider.of<ThemeProvider>(context);

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
            decoration: InputDecoration(
              hintText:
                  AppLocalizations.of(context)?.translate('services_of') ??
                      'Servicios de...',
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
      body: _filteredServices.isEmpty
          ? _buildNoResultsContent(themeProvider)
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                              color: themeProvider.cardBgColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: themeProvider.isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
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
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? const Color(0xFF3A3A3C)
                                          : Colors.blue, // Placeholder
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        topRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(context)
                                                ?.translate('image') ??
                                            'Imagen',
                                        style: TextStyle(
                                          color:
                                              themeProvider.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      service.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: themeProvider.textColor,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: themeProvider.cardBgColor,
            builder: (BuildContext modalContext) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(modalContext)
                              ?.translate('cant_find_what_looking_for') ??
                          '¿No encuentras lo que buscas?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(modalContext)
                              ?.translate('publish_request_experts') ??
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
                        Navigator.pop(modalContext); // Cerrar el modal
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
                      child: Text(
                        AppLocalizations.of(modalContext)
                                ?.translate('publish_btn') ??
                            'Publicar',
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
        child:
            const Icon(Icons.question_mark, color: Color(0xFF78BF32), size: 36),
        backgroundColor: themeProvider.isDarkMode
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFE7E7E7),
      ),
    );
  }

  Widget _buildNoResultsContent(ThemeProvider themeProvider) {
    final searchQuery = _searchController.text;
    final loc = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: themeProvider.secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty
                ? "${loc?.translate('no_results_for_query') ?? "No encontramos resultados para"} '$searchQuery'"
                : loc?.translate('no_results_found') ??
                    'No se encontraron resultados',
            style: TextStyle(
              fontSize: 18,
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
    );
  }
}
