import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../models/service_in_search.dart';
import '../models/service.dart';
import 'all_services_screen.dart';
import 'service_detail_screen.dart';

class UserServicesScreen extends StatefulWidget {
  final String userEmail;

  const UserServicesScreen({super.key, required this.userEmail});

  @override
  State<UserServicesScreen> createState() => _UserServicesScreenState();
}

class _UserServicesScreenState extends State<UserServicesScreen> {
  List<ServiceInSearch> _userServices = [];
  bool _isLoading = true;
  List<Service> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchUserServices();
    _fetchAllServices();
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
          _services = servicesJson
              .map((json) => Service.fromJson(json))
              .toList();
        });
      } else {
        print('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Widget _getStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'EN ESPERA':
        color = Colors.grey;
        break;
      case 'EN PROCESO':
        color = Colors.yellow;
        break;
      case 'TERMINADO':
        color = Colors.green;
        break;
      case 'CANCELADO':
        color = Colors.red;
        break;
      case 'RETRASADO':
        color = Colors.orange;
        break;
      case 'FINALIZADO':
        color = Colors.brown;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showServiceDetails(ServiceInSearch service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(service: service),
      ),
    );
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
                          'Mis Servicios',
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

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_userServices.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        const Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No tienes servicios asignados',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Busca o publica que necesitas',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () {
                            // Navegar a la pantalla de todos los servicios con la lista de servicios
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
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userServices.length,
                    itemBuilder: (context, index) {
                      final service = _userServices[index];
                      return GestureDetector(
                        onTap: () => _showServiceDetails(service),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Logo placeholder
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Logo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Service details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              service.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          _getStatusBadge(service.status),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        service.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${service.timeQuantity} ${service.timeUnit}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${service.createdAt.substring(0, 10)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
