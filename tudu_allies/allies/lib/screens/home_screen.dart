import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/session_service.dart';
import '../config.dart';
import 'login_screen.dart';

class AllyHomeScreen extends StatefulWidget {
  final String allyEmail;

  const AllyHomeScreen({super.key, required this.allyEmail});

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
            _InicioTab(allyEmail: widget.allyEmail),
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
              _navItem(index: 0, icon: Icons.home, label: 'Inicio'),
              _navItem(index: 1, icon: Icons.message, label: 'Mensajes'),
              _navItem(index: 2, icon: Icons.work, label: 'Mis servicios'),
              _navItem(index: 3, icon: Icons.person, label: 'Perfil'),
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
class _InicioTab extends StatelessWidget {
  final String allyEmail;

  const _InicioTab({required this.allyEmail});

  static const Color _brandColor = Color(0xFF78BF32);

  @override
  Widget build(BuildContext context) {
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
                    '¡Hola, Aliado! 👋',
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

          // Estado de verificación
          _StatusCard(),
          const SizedBox(height: 20),

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
          const Text(
            '📋 Solicitudes disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _EmptyStateCard(
            icon: Icons.assignment_outlined,
            message: 'No hay solicitudes disponibles en este momento.\n¡Vuelve más tarde!',
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  static const Color _brandColor = Color(0xFF78BF32);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC02).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pending_outlined, color: Color(0xFF815B00), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verificación en revisión',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4200),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nuestro equipo revisará tus documentos pronto. Mientras tanto, ya puedes explorar la plataforma.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
          const Text(
            'Mensajes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _EmptyStateCard(
            icon: Icons.chat_bubble_outline,
            message: 'No tienes mensajes aún.\nAquí aparecerán tus conversaciones con clientes.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Mis Servicios
// ─────────────────────────────────────────────────────────────────────────────
class _MisServiciosTab extends StatelessWidget {
  final String allyEmail;

  const _MisServiciosTab({required this.allyEmail});

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
              const Text(
                'Mis Servicios',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF78BF32),
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
          _EmptyStateCard(
            icon: Icons.work_outline,
            message: 'Aún no tienes servicios activos.\nTu servicio inicial está siendo revisado.',
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCC02)),
                  ),
                  child: const Text(
                    'Verificación Pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5D4200),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Opciones del perfil
          _profileOption(
            icon: Icons.person_outline,
            label: 'Mis datos',
            onTap: () {},
          ),
          _profileOption(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Billetera',
            onTap: () {},
          ),
          _profileOption(
            icon: Icons.star_outline,
            label: 'Mis calificaciones',
            onTap: () {},
          ),
          _profileOption(
            icon: Icons.help_outline,
            label: 'Soporte',
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
              title: const Text(
                'Cerrar sesión',
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
