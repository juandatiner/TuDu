import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_store.dart';
import '../widgets/camera_capture_mixin.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/session_service.dart';
import '../services/ally_api.dart';
import '../services/api.dart';
import '../config.dart';
import 'login_screen.dart';
import 'ally_personal_data_screen.dart';
import 'service_fix_screen.dart';
import 'service_setup_screen.dart';

class AllyHomeScreen extends StatefulWidget {
  final String allyEmail;

  /// Estado de KYC del aliado ('approved' salvo que venga de un onboarding
  /// recién terminado o de un refresco con KYC aún pendiente). Mientras no
  /// sea 'approved' puede navegar y ver todo, pero no tomar solicitudes ni
  /// aparecer visible para los usuarios (eso ya lo filtra el backend).
  final String kycStatus;

  const AllyHomeScreen({
    super.key,
    required this.allyEmail,
    this.kycStatus = 'approved',
  });

  @override
  State<AllyHomeScreen> createState() => _AllyHomeScreenState();
}

/// Azul del velo de fondo del aliado. El verde es la marca compartida con la
/// app de usuarios; este tono distingue de un vistazo en cuál de las dos estás.
const Color kAzulAliado = Color(0xFF2C7BE5);

class _AllyHomeScreenState extends State<AllyHomeScreen> {
  static const Color _bgColor = Color(0xFFF4F2F2);

  int _selectedIndex = 0;
  late IO.Socket _socket;

  /// Socket contra el backend de USERS (3000). Las solicitudes de cambio de
  /// foto viven allí, y también el evento que avisa cuando el admin decide.
  IO.Socket? _socketFotos;

  /// Foto aprobada que llega por socket. La pestaña de perfil la escucha para
  /// pintarla sin que el aliado tenga que recargar.
  final ValueNotifier<String?> _avatarEnVivo = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _conectarSocketFotos();
  }

  void _connectSocket() {
    final sessionService = Provider.of<SessionService>(context, listen: false);

    _socket = IO.io(
      Config.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          // `token` es obligatorio: el backend hace `io.use(authenticateSocket)`
          // y rechaza el handshake sin él. Antes solo se mandaba el correo, así
          // que la conexión venía fallando en silencio con `unauthorized`.
          .setAuth({
            'token': AuthStore.token,
            'device': sessionService.deviceInfo ?? '{}',
            'device_id': sessionService.deviceId,
          })
          .enableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      debugPrint('Conectado al servidor de sockets como Aliado');
    });

    _socket.onConnectError((e) {
      debugPrint('Socket de aliados rechazado: $e');
    });

    _socket.onDisconnect((_) {
      debugPrint('Desconectado del servidor de sockets');
    });
  }

  /// Escucha la decisión del admin sobre la foto de perfil.
  ///
  /// El evento lo emite el backend de users a todos los conectados, así que hay
  /// que filtrar: solo interesa el de este aliado (`owner_role: 'ally'` y su
  /// propio correo).
  void _conectarSocketFotos() {
    final sessionService = Provider.of<SessionService>(context, listen: false);

    _socketFotos = IO.io(
      Config.usersBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            'token': AuthStore.token,
            'device': sessionService.deviceInfo ?? '{}',
            'device_id': sessionService.deviceId,
          })
          .enableAutoConnect()
          .build(),
    );

    _socketFotos!.onConnectError((e) {
      debugPrint('Socket de fotos rechazado: $e');
    });

    _socketFotos!.on('photoRequestUpdated', (data) {
      if (data is! Map) return;
      if (data['owner_role'] != 'ally') return;
      if ('${data['user_email']}'.toLowerCase() !=
          widget.allyEmail.toLowerCase()) return;

      if (data['status'] == 'approved') {
        // El backend manda `new_avatar_image` a propósito en este evento; sin
        // ese campo habría que volver a pedir el perfil entero.
        _avatarEnVivo.value = data['new_avatar_image'] as String?;
      } else {
        // Rechazada: no hay foto nueva, pero el aviso de "en revisión" tiene
        // que desaparecer igual. La cadena vacía significa "ya se decidió".
        _avatarEnVivo.value = '';
      }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    _socketFotos?.dispose();
    _avatarEnVivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SafeArea(
            child: _InicioTab(allyEmail: widget.allyEmail, kycStatus: widget.kycStatus),
          ),
          SafeArea(child: _MensajesTab()),
          SafeArea(child: _MisServiciosTab(allyEmail: widget.allyEmail)),
          // Sin SafeArea acá: el degradado tiene que llegar hasta el borde de
          // arriba, y el propio tab lo aplica por dentro sobre su contenido.
          _PerfilTab(
            allyEmail: widget.allyEmail,
            kycStatus: widget.kycStatus,
            avatarEnVivo: _avatarEnVivo,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// Misma barra que la app de usuarios: `BottomNavigationBar` estándar de
  /// Material, no una fila propia. La versión anterior era un `Row` a mano que
  /// se veía distinta (otro espaciado, otro color activo) y había que mantener
  /// aparte.
  Widget _buildBottomNavBar() {
    // `removeBottom` saca el hueco reservado para el indicador de inicio, que
    // dejaba una franja vacía grande bajo los íconos. Mismo tratamiento que en
    // la app de usuarios.
    return MediaQuery(
      // Franja mínima abajo: sin nada, las etiquetas se cortaban contra el
      // borde; con la del sistema completa quedaba un hueco enorme.
      data: MediaQuery.of(context).copyWith(
        padding: MediaQuery.of(context).padding.copyWith(bottom: 6),
      ),
      child: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: context.tr('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.message), label: context.tr('messages')),
          BottomNavigationBarItem(icon: const Icon(Icons.work), label: context.tr('my_services')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: context.tr('profile')),
        ],
        currentIndex: _selectedIndex,
        // Azul: es el acento del aliado, el verde queda para la marca.
        selectedItemColor: kAzulAliado,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Inicio
// ─────────────────────────────────────────────────────────────────────────────
class _InicioTab extends StatefulWidget {
  final String allyEmail;
  final String kycStatus;

  const _InicioTab({required this.allyEmail, required this.kycStatus});

  @override
  State<_InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<_InicioTab> {
  static const Color _brandColor = Color(0xFF78BF32);

  List<Map<String, dynamic>> _solicitudes = [];
  bool _cargando = true;
  int? _aceptando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final solicitudes = await ServicioApi.disponibles();
      if (!mounted) return;
      setState(() {
        _solicitudes = solicitudes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  bool get _aprobado => widget.kycStatus == 'approved';

  Future<void> _aceptar(Map<String, dynamic> solicitud) async {
    setState(() => _aceptando = solicitud['id']);
    try {
      await ServicioApi.asignar(solicitud['id'], widget.allyEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada'), backgroundColor: _brandColor),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      final mensaje = e is ApiException ? e.message : 'No se pudo aceptar la solicitud';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
      setState(() => _aceptando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allyEmail = widget.allyEmail;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header saludo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('hello_ally'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    allyEmail,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
              // Logo mini
              Column(
                children: [
                  Text(
                    'Tu',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 22,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                  Text(
                    'Du',
                    style: TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 22,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_aprobado) ...[
            _AvisoRevision(),
            const SizedBox(height: 20),
          ],

          // Resumen métricas
          Row(
            children: [
              Expanded(child: _MetricCard(value: '0', label: 'Servicios\ncompletados', icon: Icons.check_circle_outline)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(value: '\$0', label: 'Ganancias\neste mes', icon: Icons.account_balance_wallet_outlined)),
            ],
          ),
          const SizedBox(height: 20),

          // Sección solicitudes
          Text(context.tr('available_requests'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _brandColor),
              ),
            )
          else if (_solicitudes.isEmpty)
            _EmptyStateCard(
              icon: Icons.assignment_outlined,
              message: context.tr('no_requests'),
            )
          else
            ..._solicitudes.map((s) => _SolicitudCard(
                  solicitud: s,
                  cargando: _aceptando == s['id'],
                  bloqueado: !_aprobado,
                  onAceptar: () => _aceptar(s),
                )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  static const Color _brandColor = Color(0xFF78BF32);

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _brandColor, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.black.withOpacity(0.15)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.4),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Único aviso de revisión de cuenta en toda la app.
///
/// Antes se repetía en el Home y en el Perfil, y el aliado leía lo mismo dos
/// veces. Se queda en el Home, que es donde importa: es la pantalla donde ve
/// las solicitudes que todavía no puede tomar.
class _AvisoRevision extends StatelessWidget {
  static const Color _naranja = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _naranja.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _naranja.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: _naranja, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('review_banner_title'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('review_banner_body'),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.6),
                      height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final Map<String, dynamic> solicitud;
  final bool cargando;
  final bool bloqueado;
  final VoidCallback onAceptar;

  static const Color _brandColor = Color(0xFF78BF32);

  const _SolicitudCard({
    required this.solicitud,
    required this.cargando,
    this.bloqueado = false,
    required this.onAceptar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            solicitud['title'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          if ((solicitud['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              solicitud['description'],
              style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.55), height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (solicitud['budget'] != null) ...[
                Icon(Icons.attach_money, size: 16, color: _brandColor),
                Text('${solicitud['budget']}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brandColor)),
                const SizedBox(width: 14),
              ],
              if (solicitud['time_quantity'] != null) ...[
                Icon(Icons.schedule, size: 16, color: Colors.black.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text('${solicitud['time_quantity']} ${solicitud['time_unit'] ?? ''}',
                    style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.55))),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (cargando || bloqueado) ? null : onAceptar,
              style: ElevatedButton.styleFrom(
                backgroundColor: bloqueado ? Colors.grey.shade300 : _brandColor,
                foregroundColor: bloqueado ? Colors.black45 : Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.black45,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: cargando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(bloqueado ? 'Cuenta en revisión' : 'Aceptar solicitud',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Mensajes
// ─────────────────────────────────────────────────────────────────────────────
class _MensajesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('messages'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _EmptyStateCard(
            icon: Icons.chat_bubble_outline,
            message: context.tr('no_messages'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Mis Servicios
// ─────────────────────────────────────────────────────────────────────────────
class _MisServiciosTab extends StatefulWidget {
  final String allyEmail;

  const _MisServiciosTab({required this.allyEmail});

  @override
  State<_MisServiciosTab> createState() => _MisServiciosTabState();
}

class _MisServiciosTabState extends State<_MisServiciosTab> {
  static const Color _brandColor = Color(0xFF78BF32);

  List<Map<String, dynamic>> _perfiles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final perfiles = await ServicioApi.misPerfiles(widget.allyEmail);
      if (!mounted) return;
      setState(() {
        _perfiles = perfiles;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Corregir un servicio rechazado. Al volver se recarga: el estado pasó de
  /// `rejected` a `pending` y la tarjeta tiene que reflejarlo.
  Future<void> _corregir(Map<String, dynamic> servicio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceFixScreen(servicio: servicio, email: widget.allyEmail),
      ),
    );
    if (mounted) _cargar();
  }

  Future<void> _agregar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceSetupScreen(email: widget.allyEmail, esOpcional: true),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('my_services_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('add')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _brandColor),
              ),
            )
          else if (_perfiles.isEmpty)
            _EmptyStateCard(
              icon: Icons.work_outline,
              message: context.tr('no_active_services'),
            )
          else
            ..._perfiles.map((p) => _MiServicioCard(perfil: p, onCorregir: _corregir)),
        ],
      ),
    );
  }
}

/// Uno de los servicios propios del aliado, con su estado de revisión.
class _MiServicioCard extends StatelessWidget {
  final Map<String, dynamic> perfil;

  /// Abre la pantalla de corrección de un servicio rechazado.
  final void Function(Map<String, dynamic> servicio) onCorregir;

  static const Color _brandColor = Color(0xFF78BF32);

  const _MiServicioCard({required this.perfil, required this.onCorregir});

  /// Nombre visible de cada campo que el admin puede marcar al rechazar.
  static String _nombreCampo(BuildContext context, String campo) {
    switch (campo) {
      case 'name':
        return context.tr('new_service_name');
      case 'description':
        return context.tr('new_service_description');
      case 'portfolio':
        return context.tr('portfolio_title');
      case 'category':
        return context.tr('service_category');
      default:
        return campo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = perfil['service'] as Map<String, dynamic>?;
    final categoria = servicio?['category'] as Map<String, dynamic>?;
    final estado = servicio?['review_status'] ?? 'pending';
    final estadoCategoria = categoria?['review_status'] ?? 'approved';
    final campos =
        ((servicio?['rejected_fields'] as List?) ?? []).map((c) => c.toString()).toList();

    late final Color color;
    late final String texto;
    switch (estado) {
      case 'approved':
        color = _brandColor;
        texto = context.tr('review_approved');
        break;
      case 'rejected':
        color = Colors.red;
        texto = context.tr('review_rejected');
        break;
      default:
        color = Colors.orange;
        texto = context.tr('review_pending');
    }

    // El admin decide servicio y categoría por separado: un servicio puede
    // seguir en espera porque lo que falta aprobar es la categoría nueva que
    // propuso el aliado. Sin decirlo, el aliado no entiende la demora.
    final notaServicio = servicio?['admin_note'] as String?;
    String? aviso;
    if (estado != 'approved') {
      if (estadoCategoria == 'rejected') {
        aviso = context.tr('review_category_rejected');
      } else if (estadoCategoria != 'approved') {
        aviso = context.tr('review_waiting_category');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servicio?['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    if (categoria?['name'] != null) ...[
                      const SizedBox(height: 2),
                      Text(categoria!['name'],
                          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                    ],
                    if ((perfil['nombre_comercial'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(perfil['nombre_comercial'],
                          style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.55))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Text(texto,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: Colors.black.withOpacity(0.45)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(aviso,
                      style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6))),
                ),
              ],
            ),
          ],
          // Motivo del rechazo: es lo único que le dice al aliado qué corregir.
          if (estado == 'rejected') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('review_reason_title'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  if (notaServicio != null && notaServicio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notaServicio,
                        style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75))),
                  ],
                  if (campos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: campos
                          .map((c) => Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(_nombreCampo(context, c),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onCorregir(servicio!),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.tr('fix_and_resend')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Perfil
// ─────────────────────────────────────────────────────────────────────────────

/// Perfil del aliado, al estilo de la pantalla de perfil de la app de usuarios:
/// nombre a la izquierda, foto a la derecha, y debajo las opciones.
///
/// Dos cosas propias del aliado:
///  - **Verificación:** con el KYC aprobado se muestra el chulito; mientras el
///    admin no lo revise, una banda naranja arriba lo recuerda.
///  - **Foto:** no se cambia en el acto. Pasa por la misma revisión que la de un
///    cliente, así que mientras hay una solicitud pendiente se avisa.
class _PerfilTab extends StatefulWidget {
  final String allyEmail;

  /// Estado del KYC que ya venía resuelto desde el enrutado.
  final String kycStatus;

  /// Foto aprobada que llega por socket desde el backend de users. Cadena
  /// vacía = el admin ya decidió pero no hay foto nueva (la rechazó).
  final ValueNotifier<String?> avatarEnVivo;

  const _PerfilTab({
    required this.allyEmail,
    required this.avatarEnVivo,
    this.kycStatus = 'approved',
  });

  @override
  State<_PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<_PerfilTab> {
  static const Color _brandColor = Color(0xFF78BF32);

  Map<String, dynamic> _ally = const {};
  bool _cargando = true;

  bool get _verificado => (_ally['kyc_status'] ?? widget.kycStatus) == 'approved';

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.avatarEnVivo.addListener(_aplicarAvatarEnVivo);
  }

  @override
  void dispose() {
    widget.avatarEnVivo.removeListener(_aplicarAvatarEnVivo);
    super.dispose();
  }

  /// El admin decidió sobre la foto mientras el aliado tenía la app abierta.
  void _aplicarAvatarEnVivo() {
    final nueva = widget.avatarEnVivo.value;
    if (nueva == null || !mounted) return;

    setState(() {
      // Cadena vacía = rechazada: no se toca la foto, pero deja de estar en
      // revisión.
      if (nueva.isNotEmpty) _ally = {..._ally, 'avatar_image': nueva};
    });

    _avisar(nueva.isNotEmpty
        ? context.tr('photo_approved')
        : context.tr('photo_rejected'));
  }

  Future<void> _cargar() async {
    try {
      final estado = await AliadoApi.estado(widget.allyEmail);
      if (!mounted) return;
      setState(() {
        _ally = estado['ally'] is Map
            ? Map<String, dynamic>.from(estado['ally'])
            : const {};
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Solo galería, igual que la foto de perfil en la app de usuarios. La
  /// cámara queda para el KYC, que sí se toma en vivo.
  void _avisar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: esError ? Colors.red : _brandColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _brandColor));
    }

    // Solo el nombre comercial: es con el que lo ve el cliente. El nombre
    // personal y el correo son datos internos y viven en "Mis datos".
    final comercial = (_ally['nombre_comercial'] as String?) ?? '';

    // Banda sólida con el borde inferior redondeado, igual que el perfil de la
    // app de usuarios pero en azul.
    return Stack(
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: kAzulAliado.withOpacity(0.16),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
        ),
        SafeArea(
        child: RefreshIndicator(
      color: kAzulAliado,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Las medidas de acá abajo están copiadas del perfil de users para que
        // las dos pantallas queden a la misma altura: padding 16, separación 5
        // sobre el nombre y 15 antes de los accesos, avatar de 80 con borde 3.
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 5),

            // Nombre a la izquierda, foto a la derecha — igual que en users.
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            comercial.isEmpty ? widget.allyEmail : comercial,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_verificado) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified, size: 22, color: _brandColor),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: _buildFoto(),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Los tres accesos rápidos, como en el perfil de la app de
            // usuarios. Lo que está acá arriba no se repite en la lista.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _accesoRapido(
                  icon: Icons.support_agent,
                  label: context.tr('support'),
                  onTap: () {},
                ),
                _accesoRapido(
                  icon: Icons.badge_outlined,
                  label: context.tr('my_data'),
                  onTap: _abrirMisDatos,
                ),
                _accesoRapido(
                  icon: Icons.account_balance_wallet_outlined,
                  label: context.tr('wallet'),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            _profileOption(
              icon: Icons.star_outline,
              label: context.tr('my_ratings'),
              onTap: () {},
            ),
            const SizedBox(height: 8),

            // Cerrar sesión
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: Text(context.tr('close_session'),
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  final sessionService =
                      Provider.of<SessionService>(context, listen: false);
                  await sessionService.logout();

                  if (!context.mounted) return;

                  Navigator.of(context).pop(); // Quitar loading
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      ),
      ],
    );
  }

  /// Solo la foto, sin botón de cámara encima: en el perfil de la app de
  /// usuarios el avatar tampoco se toca. La foto se cambia desde "Mis datos",
  /// que es el único lugar donde se editan los datos.
  Widget _buildFoto() {
    final url = (_ally['avatar_image'] as String?) ?? '';

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: url.isEmpty ? kAzulAliado.withOpacity(0.15) : Colors.transparent,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.person, size: 40, color: kAzulAliado.withOpacity(0.7))
          : Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person, size: 40, color: kAzulAliado.withOpacity(0.7))),
    );
  }

  Future<void> _abrirMisDatos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllyPersonalDataScreen(email: widget.allyEmail),
      ),
    );
    // Puede haber cambiado el nombre, el perfil o la foto.
    if (mounted) _cargar();
  }

  /// Tarjeta cuadrada de acceso rápido, con la misma forma que las de users.
  Widget _accesoRapido({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: kAzulAliado),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _brandColor, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}
