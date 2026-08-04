import 'package:flutter/material.dart';
import '../config.dart';
import 'kyc_review_screen.dart';
import '../services/admin_api.dart';
import 'photo_change_requests_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  int _pendingRequestsCount = 0; // solicitudes pendientes totales (leídas o no)
  int _unreadRequestsCount = 0;   // solicitudes pendientes NO leídas
  int _pendingKycCount = 0;       // verificaciones de identidad sin revisar
  bool _isLoading = true;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
    _loadPendingKycCount();
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
          'forceNew': true,
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

    _socket.on('newPhotoChangeRequest', (_) {
      _loadPendingRequestsCount();
    });

    _socket.on('photoRequestUpdated', (_) {
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
    // Cargar los contadores de pendientes cada vez que la pantalla se activa
    _loadPendingRequestsCount();
    _loadPendingKycCount();
  }

  /// Aliados con documentos subidos y todavía sin decisión.
  Future<void> _loadPendingKycCount() async {
    try {
      final pendientes = await KycAdminApi.listar(estado: 'submitted');
      if (!mounted) return;
      setState(() => _pendingKycCount = pendientes.length);
    } catch (e) {
      print('Error loading pending KYC count: $e');
    }
  }

  Future<void> _loadPendingRequestsCount() async {
    try {
      final todas = await SolicitudFotoAdminApi.listar();

        final allPending =
            todas.where((r) => r['status'] == 'pending').toList();
        final unread = allPending
            .where((r) => r['read_at'] == null)
            .toList();
        setState(() {
          _pendingRequestsCount = allPending.length;
          _unreadRequestsCount = unread.length;
          _isLoading = false;
        });
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
                  if (_pendingRequestsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (_unreadRequestsCount > 0
                                ? Colors.red
                                : Colors.orange)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_unreadRequestsCount > 0
                                  ? Colors.red
                                  : Colors.orange)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _unreadRequestsCount > 0
                                ? Icons.notifications_active
                                : Icons.pending_actions,
                            size: 20,
                            color: _unreadRequestsCount > 0
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_pendingRequestsCount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _unreadRequestsCount > 0
                                  ? Colors.red
                                  : Colors.orange,
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
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Aliados: mismo patrón de tarjetas que Usuarios, para no tener dos
        // formas distintas de entrar a lo mismo.
        Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Aliados',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_pendingKycCount > 0) _contadorPendientes(_pendingKycCount),
                ],
              ),
              const SizedBox(height: 8),
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
                      _buildDashboardCard(
                        'Verificación de Identidad',
                        '',
                        Icons.badge,
                        Colors.green,
                        const _KycReviewPage(),
                        _pendingKycCount,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ];

  /// Píldora con el número de pendientes, en rojo si hay sin revisar.
  Widget _contadorPendientes(int cantidad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, size: 20, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            '$cantidad',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Config.primaryColor,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.people),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _unreadRequestsCount > 0
                            ? Colors.red
                            : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Usuarios',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.business),
                if (_pendingKycCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
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
        ).then((_) {
          _loadPendingRequestsCount();
          _loadPendingKycCount();
        });
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

/// La revisión de identidad ahora se abre como pantalla propia desde la
/// tarjeta, igual que las solicitudes de cambio de foto.
class _KycReviewPage extends StatelessWidget {
  const _KycReviewPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Verificación de Identidad'),
        backgroundColor: Config.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const KycReviewScreen(),
    );
  }
}
