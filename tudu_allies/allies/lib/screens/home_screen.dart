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

class _AllyHomeScreenState extends State<AllyHomeScreen> {
  static const Color _brandColor = Color(0xFF78BF32);
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
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _InicioTab(allyEmail: widget.allyEmail, kycStatus: widget.kycStatus),
            _MensajesTab(),
            _MisServiciosTab(allyEmail: widget.allyEmail),
            _PerfilTab(
              allyEmail: widget.allyEmail,
              kycStatus: widget.kycStatus,
              avatarEnVivo: _avatarEnVivo,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(index: 0, icon: Icons.home, label: context.tr('home')),
              _navItem(index: 1, icon: Icons.message, label: context.tr('messages')),
              _navItem(index: 2, icon: Icons.work, label: context.tr('my_services')),
              _navItem(index: 3, icon: Icons.person, label: context.tr('profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        splashColor: _brandColor.withOpacity(0.15),
        highlightColor: _brandColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? _brandColor : Colors.black.withOpacity(0.4),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? _brandColor : Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
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

/// Una solicitud de un usuario, sin asignar todavía, con botón para tomarla.
class _AvisoRevision extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5A623).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF5A623), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuenta en revisión: tus servicios no serán visibles y no puedes tomar solicitudes todavía.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.35),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nuestro equipo revisará tu cuenta lo más rápido posible.',
                  style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6), height: 1.35),
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

class _PerfilTabState extends State<_PerfilTab> with CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);

  Map<String, dynamic> _ally = const {};
  Map<String, dynamic>? _fotoPendiente;
  bool _cargando = true;
  bool _enviandoFoto = false;

  bool get _verificado => (_ally['kyc_status'] ?? widget.kycStatus) == 'approved';

  @override
  void initState() {
    super.initState();
    detectarDispositivo();
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
      _fotoPendiente = null;
    });

    _avisar(nueva.isNotEmpty
        ? context.tr('photo_approved')
        : context.tr('photo_rejected'));
  }

  Future<void> _cargar() async {
    try {
      final estado = await AliadoApi.estado(widget.allyEmail);
      final pendiente = await SolicitudFotoAliadoService.pendiente(widget.allyEmail);
      if (!mounted) return;
      setState(() {
        _ally = estado['ally'] is Map
            ? Map<String, dynamic>.from(estado['ally'])
            : const {};
        _fotoPendiente = pendiente;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Solo galería, igual que la foto de perfil en la app de usuarios. La
  /// cámara queda para el KYC, que sí se toma en vivo.
  Future<void> _cambiarFoto() async {
    await tomarFoto(
      etiqueta: 'PERFIL',
      source: ImageSource.gallery,
      onListo: (archivo) async {
        setState(() => _enviandoFoto = true);
        try {
          await SolicitudFotoAliadoService.crear(
            widget.allyEmail,
            base64Encode(await archivo.readAsBytes()),
          );
          if (!mounted) return;
          _avisar(context.tr('photo_under_review'));
          await _cargar();
        } catch (e) {
          if (!mounted) return;
          _avisar(e is ApiException ? e.message : context.tr('connection_error'),
              esError: true);
        } finally {
          if (mounted) setState(() => _enviandoFoto = false);
        }
      },
    );
  }

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

    final nombre =
        '${_ally['nombre'] ?? ''} ${_ally['apellido'] ?? ''}'.trim();
    final comercial = (_ally['nombre_comercial'] as String?) ?? '';
    final frase = (_ally['frase_presentacion'] as String?) ?? '';

    return RefreshIndicator(
      color: _brandColor,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_verificado) _bandaEnRevision(),
            const SizedBox(height: 10),

            // Nombre a la izquierda, foto a la derecha — igual que en users.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nombre.isEmpty ? widget.allyEmail : nombre,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_verificado) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, size: 20, color: _brandColor),
                          ],
                        ],
                      ),
                      if (comercial.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(comercial,
                            style: TextStyle(
                                fontSize: 14, color: Colors.black.withOpacity(0.6))),
                      ],
                      const SizedBox(height: 2),
                      Text(widget.allyEmail,
                          style: TextStyle(
                              fontSize: 12, color: Colors.black.withOpacity(0.45))),
                      if (_verificado) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 13, color: _brandColor),
                            const SizedBox(width: 4),
                            Text(context.tr('verified_badge'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: _brandColor,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildFoto(),
              ],
            ),

            if (frase.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
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
                child: Text('"$frase"',
                    style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black.withOpacity(0.7))),
              ),
            ],

            const SizedBox(height: 28),

            _profileOption(
              icon: Icons.person_outline,
              label: context.tr('my_data'),
              onTap: () {},
            ),
            _profileOption(
              icon: Icons.account_balance_wallet_outlined,
              label: context.tr('wallet'),
              onTap: () {},
            ),
            _profileOption(
              icon: Icons.star_outline,
              label: context.tr('my_ratings'),
              onTap: () {},
            ),
            _profileOption(
              icon: Icons.support_agent,
              label: context.tr('support'),
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
    );
  }

  /// Mientras el admin no apruebe el KYC. Naranja y arriba de todo: es lo que
  /// explica por qué todavía no puede tomar solicitudes.
  Widget _bandaEnRevision() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time, size: 18, color: Colors.orange.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('account_under_review_short'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900)),
                const SizedBox(height: 2),
                Text(context.tr('kyc_pending_body'),
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.orange.shade900, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoto() {
    final url = (_ally['avatar_image'] as String?) ?? '';
    final enRevision = _fotoPendiente != null;

    return GestureDetector(
      onTap: _enviandoFoto ? null : _cambiarFoto,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brandColor.withOpacity(0.15),
                  border: Border.all(color: _brandColor, width: 2.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: url.isEmpty
                    ? const Icon(Icons.person, size: 44, color: _brandColor)
                    : Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, size: 44, color: _brandColor)),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                    color: _brandColor, shape: BoxShape.circle),
                child: _enviandoFoto
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.photo_camera, size: 13, color: Colors.white),
              ),
            ],
          ),
          if (enRevision) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 90,
              child: Text(
                context.tr('photo_under_review'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.orange.shade900),
              ),
            ),
          ],
        ],
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
