import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'photo_change_requests_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  int _pendingRequestsCount = 0;
  bool _isLoading = true;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
    _connectSocket();
  }

  void _connectSocket() {
    // Conectar al servidor Socket.io
    _socket = IO.io(
        Config.baseUrl
            .replaceAll('http://', 'ws://')
            .replaceAll('https://', 'wss://'),
        {
          'transports': ['websocket'],
          'autoConnect': true,
        });

    _socket.onConnect((_) {
      print('Conectado al servidor Socket.io');
    });

    _socket.onConnectError((error) {
      print('Error de conexión Socket.io: $error');
    });

    _socket.onDisconnect((_) {
      print('Desconectado del servidor Socket.io');
    });

    // Escuchar evento de nueva solicitud
    _socket.on('newPhotoChangeRequest', (data) {
      print('Nueva solicitud recibida en dashboard: $data');
      // Actualizar el contador de solicitudes pendientes
      _loadPendingRequestsCount();
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cargar el contador de pendientes cada vez que la pantalla se activa
    _loadPendingRequestsCount();
  }

  Future<void> _loadPendingRequestsCount() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/api/admin/photo-change-requests'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pendingRequests =
            data['data'].where((request) => request['status'] == 'pending');
        setState(() {
          _pendingRequestsCount = pendingRequests.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pending requests count: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Widget> get _pages => [
        // Inicio
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Panel de Administración',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 32),
              const Icon(
                Icons.dashboard,
                size: 100,
                color: Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'Bienvenido al panel de administración',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Usuarios
        Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Solicitudes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_pendingRequestsCount',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Grid de solicitudes 2x2 responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  final childAspectRatio =
                      constraints.maxWidth > 600 ? 0.9 : 0.85;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: childAspectRatio,
                    children: [
                      // Solicitudes de cambio de foto
                      _buildDashboardCard(
                        'Cambio de Foto de Perfil',
                        '',
                        Icons.photo,
                        Colors.blue,
                        const PhotoChangeRequestsScreen(),
                        _pendingRequestsCount,
                      ),
                      // Otra solicitud
                      _buildDashboardCard(
                        'Solicitud 2',
                        '',
                        Icons.request_page,
                        Colors.green,
                        const PhotoChangeRequestsScreen(),
                      ),
                      // Otra solicitud
                      _buildDashboardCard(
                        'Solicitud 3',
                        '',
                        Icons.request_page,
                        Colors.orange,
                        const PhotoChangeRequestsScreen(),
                      ),
                      // Otra solicitud
                      _buildDashboardCard(
                        'Solicitud 4',
                        '',
                        Icons.request_page,
                        Colors.purple,
                        const PhotoChangeRequestsScreen(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Aliados
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Gestión de Aliados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 32),
              const Icon(
                Icons.business,
                size: 100,
                color: Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'Funcionalidad en construcción',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Config.primaryColor,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Usuarios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Aliados',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Config.primaryColor,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    String description,
    IconData icon,
    Color color,
    Widget screen, [
    int pendingCount = 0,
  ]) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Card(
        elevation: 4,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: title == 'Cambio de Foto de Perfil'
                          ? Image.asset(
                              'assets/images/usuarios-de-perfil.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            )
                          : Icon(
                              icon,
                              size: 50,
                              color: color,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (description.isNotEmpty) const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Center(
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
