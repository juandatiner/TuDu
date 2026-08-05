import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/session_service.dart';
import '../services/ally_api.dart';
import '../services/api.dart';
import '../config.dart';
import 'login_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    
    _socket = IO.io(
      Config.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            'email': widget.allyEmail,
            'device': sessionService.deviceInfo ?? '{}'
          })
          .enableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      debugPrint('Conectado al servidor de sockets como Aliado');
    });

    _socket.onDisconnect((_) {
      debugPrint('Desconectado del servidor de sockets');
    });
  }

  @override
  void dispose() {
    _socket.dispose();
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
            _PerfilTab(allyEmail: widget.allyEmail),
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
            ..._perfiles.map((p) => _MiServicioCard(perfil: p)),
        ],
      ),
    );
  }
}

/// Uno de los servicios propios del aliado, con su estado de revisión.
class _MiServicioCard extends StatelessWidget {
  final Map<String, dynamic> perfil;

  static const Color _brandColor = Color(0xFF78BF32);

  const _MiServicioCard({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final servicio = perfil['service'] as Map<String, dynamic>?;
    final estado = servicio?['review_status'] ?? 'pending';

    late final Color color;
    late final String texto;
    switch (estado) {
      case 'approved':
        color = _brandColor;
        texto = 'Aprobado';
        break;
      case 'rejected':
        color = Colors.red;
        texto = 'Rechazado';
        break;
      default:
        color = Colors.orange;
        texto = 'En revisión';
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio?['name'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Perfil
// ─────────────────────────────────────────────────────────────────────────────
class _PerfilTab extends StatelessWidget {
  final String allyEmail;

  static const Color _brandColor = Color(0xFF78BF32);

  const _PerfilTab({required this.allyEmail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),

          // Avatar y nombre
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brandColor.withOpacity(0.15),
                    border: Border.all(color: _brandColor, width: 2.5),
                  ),
                  child: Center(
                    child: Icon(Icons.person, size: 48, color: _brandColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  allyEmail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Opciones del perfil
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
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                final sessionService = Provider.of<SessionService>(context, listen: false);
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
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.black.withOpacity(0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
