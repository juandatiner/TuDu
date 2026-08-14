import 'package:flutter/material.dart';
import '../config.dart';
import 'kyc_review_screen.dart';
import 'profile_changes_review_screen.dart';
import 'services_review_screen.dart';
import 'services_catalog_screen.dart';
import '../services/admin_api.dart';
import '../services/auth_store.dart';
import 'photo_change_requests_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  // 0 = contenido normal de la pestaña, 1 = Soporte. Vive fuera de las
  // pestañas de Usuarios/Aliados nada más — Servicios no tiene este switch.
  int _seccionActiva = 0;
  int _pendingRequestsCount = 0; // solicitudes pendientes totales (leídas o no)
  int _unreadRequestsCount = 0;   // solicitudes pendientes NO leídas
  int _pendingKycCount = 0;       // verificaciones de identidad sin revisar
  int _pendingServiciosCount = 0; // categorías/servicios propuestos sin revisar
  int _pendingPerfilesCount = 0;  // cambios de perfil de aliado sin revisar
  int _pendingKycUsuariosCount = 0; // verificaciones de identidad de clientes
  bool _isLoading = true;
  late IO.Socket _socket;         // users (3000): solicitudes de foto
  late IO.Socket _socketAliados;  // aliados (3002): cambios de perfil

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
    _loadPendingKycCount();
    _loadPendingServiciosCount();
    _loadPendingPerfilesCount();
    _loadPendingKycUsuariosCount();
    _connectSocket();
  }

  /// El panel escucha dos backends porque las colas viven en dos sitios: las
  /// fotos en el de users (3000) y todo lo de aliados en el suyo (3002).
  ///
  /// Los dos exigen el token en el handshake (`io.use(authenticateSocket)`):
  /// sin él la conexión se rechaza con `unauthorized` y los contadores solo se
  /// refrescaban al volver a entrar a la pantalla.
  void _connectSocket() {
    _socket = _abrirSocket(Config.baseUrl, 'users');
    _socket.on('newPhotoChangeRequest', (_) => _loadPendingRequestsCount());
    _socket.on('photoRequestUpdated', (_) => _loadPendingRequestsCount());
    _socket.on('newUserKyc', (_) => _loadPendingKycUsuariosCount());
    _socket.on('userKycUpdated', (_) => _loadPendingKycUsuariosCount());

    _socketAliados = _abrirSocket(Config.alliesBaseUrl, 'aliados');
    _socketAliados.on(
        'newAllyProfileChangeRequest', (_) => _loadPendingPerfilesCount());
    _socketAliados.on(
        'allyProfileReviewed', (_) => _loadPendingPerfilesCount());
  }

  IO.Socket _abrirSocket(String base, String nombre) {
    final socket = IO.io(
      base.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://'),
      {
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        'auth': {'token': AuthStore.token},
      },
    );

    socket.onConnect((_) => print('Socket.io conectado ($nombre)'));
    socket.onConnectError((e) => print('Socket.io error ($nombre): $e'));
    socket.onDisconnect((_) => print('Socket.io desconectado ($nombre)'));

    return socket;
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socketAliados.disconnect();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cargar los contadores de pendientes cada vez que la pantalla se activa
    _loadPendingRequestsCount();
    _loadPendingKycCount();
    _loadPendingServiciosCount();
    _loadPendingPerfilesCount();
    _loadPendingKycUsuariosCount();
  }

  /// Clientes que subieron sus documentos y todavía nadie revisó.
  Future<void> _loadPendingKycUsuariosCount() async {
    try {
      final pendientes = await KycAdminApi.listar(
          estado: 'submitted', ruta: KycAdminApi.rutaUsuarios);
      if (!mounted) return;
      setState(() => _pendingKycUsuariosCount = pendientes.length);
    } catch (e) {
      print('Error loading pending user KYC count: $e');
    }
  }

  /// Cambios de perfil comercial que un aliado propuso y nadie revisó.
  Future<void> _loadPendingPerfilesCount() async {
    try {
      final pendientes = await CambiosPerfilAdminApi.listar(estado: 'pending');
      if (!mounted) return;
      setState(() => _pendingPerfilesCount = pendientes.length);
    } catch (e) {
      print('Error loading pending profile changes count: $e');
    }
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

  /// Categorías o servicios propuestos por un aliado, todavía sin decisión.
  Future<void> _loadPendingServiciosCount() async {
    try {
      final pendientes = await ServiciosAdminApi.listar(estado: 'pending');
      if (!mounted) return;
      setState(() => _pendingServiciosCount = pendientes.length);
    } catch (e) {
      print('Error loading pending services count: $e');
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
        // Usuarios
        Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
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
                      _buildDashboardCard(
                        'Verificación de Identidad',
                        '',
                        Icons.badge,
                        Colors.green,
                        const _KycUsuariosPage(),
                        _pendingKycUsuariosCount,
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
                      _buildDashboardCard(
                        'Servicios propuestos',
                        '',
                        Icons.miscellaneous_services,
                        Colors.purple,
                        const _ServiciosReviewPage(),
                        _pendingServiciosCount,
                      ),
                      _buildDashboardCard(
                        'Cambios de perfil',
                        '',
                        Icons.fact_check_outlined,
                        Colors.teal,
                        const _CambiosPerfilPage(),
                        _pendingPerfilesCount,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Servicios: catálogo aprobado, solo visualización.
        const ServiciosCatalogoScreen(),
      ];

  /// Usuarios y Aliados dividen el título en dos mitades clicables — Panel
  /// de Administración / Soporte — mismo tamaño que el título fijo (22,
  /// bold), separadas por una línea vertical. Servicios trae su propio
  /// AppBar (con su propio título dividido) — acá no se dibuja nada para
  /// esa pestaña, así no queda duplicado.
  Widget _tituloAppBar() {
    const estiloTitulo = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
    const opciones = ['Panel de Administración', 'Soporte'];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < opciones.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black26,
              ),
            GestureDetector(
              onTap: () => setState(() => _seccionActiva = i),
              child: Text(
                opciones[i],
                style: estiloTitulo.copyWith(
                  color: _seccionActiva == i ? Colors.black : Colors.black38,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Placeholder de Soporte — todavía no hay backend/flujo para esto.
  Widget _paginaSoporte() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, size: 72, color: Colors.black26),
            const SizedBox(height: 14),
            Text(
              'Muy pronto vas a poder gestionar soporte desde acá.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 2
          ? null
          : AppBar(
              centerTitle: true,
              title: _tituloAppBar(),
            ),
      body: (_selectedIndex != 2 && _seccionActiva == 1)
          ? _paginaSoporte()
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
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
                if (_pendingKycCount > 0 || _pendingServiciosCount > 0)
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            label: 'Servicios',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Config.primaryColor,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _seccionActiva = 0;
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
          _loadPendingServiciosCount();
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
      ),
      body: const KycReviewScreen(),
    );
  }
}

/// Verificación de identidad de los clientes: misma pantalla que la de
/// aliados, apuntando a la cola del backend de users.
class _KycUsuariosPage extends StatelessWidget {
  const _KycUsuariosPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Verificación de Identidad'),
      ),
      body: const KycReviewScreen(ruta: KycAdminApi.rutaUsuarios),
    );
  }
}

/// Cambios al perfil comercial de un aliado, misma envoltura que KYC.
class _CambiosPerfilPage extends StatelessWidget {
  const _CambiosPerfilPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Cambios de perfil'),
      ),
      body: const CambiosPerfilReviewScreen(),
    );
  }
}

/// Revisión de categorías/servicios propuestos, misma envoltura que KYC.
class _ServiciosReviewPage extends StatelessWidget {
  const _ServiciosReviewPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Servicios propuestos'),
      ),
      body: const ServiciosReviewScreen(),
    );
  }
}
