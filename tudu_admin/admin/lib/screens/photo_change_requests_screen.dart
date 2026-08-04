import 'package:flutter/material.dart';
import 'dart:convert';
import '../config.dart';
import '../services/admin_api.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PhotoChangeRequestsScreen extends StatefulWidget {
  const PhotoChangeRequestsScreen({super.key});

  @override
  State<PhotoChangeRequestsScreen> createState() =>
      _PhotoChangeRequestsScreenState();
}

class _PhotoChangeRequestsScreenState extends State<PhotoChangeRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _loadRequests();
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

    _socket.on('newPhotoChangeRequest', (data) {
      if (!mounted) return;
      _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nueva solicitud de cambio de foto'),
          backgroundColor: Config.primaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final todas = await SolicitudFotoAdminApi.listar();

      {
        setState(() {
          // Mostrar todas las solicitudes pendientes (leídas o no)
          _requests =
              todas.where((r) => r['status'] == 'pending').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await SolicitudFotoAdminApi.marcarLeida(id);
      // Actualizar localmente para reflejar el cambio
      setState(() {
        final idx = _requests.indexWhere((r) => r['id'] == id);
        if (idx != -1) {
          _requests[idx] = Map.from(_requests[idx])
            ..['read_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      // Silencioso: no es crítico
    }
  }

  Future<void> _handleRequest(int id, String status, {String? rejectionReason}) async {
    try {
      final body = {'status': status};
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        body['rejection_reason'] = rejectionReason;
      }
      await SolicitudFotoAdminApi.resolver(id, status,
          motivoRechazo: body['rejection_reason'] as String?);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved'
                ? 'Solicitud aprobada'
                : 'Solicitud rechazada'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showRejectionReasonDialog(BuildContext ctx) async {
    final controller = TextEditingController();
    String? selectedReason = 'Contenido Sexual';
    final options = [
      'Contenido Sexual',
      'Violencia / Ofensivo',
      'Identidad Falsa',
      'Baja Calidad',
      'Otro'
    ];

    return showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text('Razón del rechazo', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: options.map((option) {
                      final isSelected = selectedReason == option;
                      return ChoiceChip(
                        label: Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.red.shade400,
                        backgroundColor: Colors.grey.shade200,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedReason = option;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedReason == 'Otro') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Especifica la razón...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  String finalReason = selectedReason!;
                  if (selectedReason == 'Contenido Sexual') finalReason = 'reason_sexual';
                  if (selectedReason == 'Violencia / Ofensivo') finalReason = 'reason_offensive';
                  if (selectedReason == 'Identidad Falsa') finalReason = 'reason_fake';
                  if (selectedReason == 'Baja Calidad') finalReason = 'reason_quality';

                  if (selectedReason == 'Otro') {
                    finalReason = controller.text.trim();
                    if (finalReason.isEmpty) finalReason = 'reason_other';
                  }

                  Navigator.pop(dialogCtx, finalReason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirmar Rechazo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Cambio de Foto'),
        backgroundColor: Config.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child:
                      Text('No hay solicitudes de cambio de foto pendientes'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return GestureDetector(
                      onTap: () {
                        _markAsRead(request['id']);
                        _showRequestDetail(context, request);
                      },
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: request['read_at'] == null
                                ? Colors.red.withOpacity(0.6)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Indicador NO leído
                              if (request['read_at'] == null)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${request['nombre']} ${request['apellido']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: request['read_at'] == null
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      request['user_email'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatDate(request['created_at'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(request['status']),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(request['status']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showRequestDetail(BuildContext context, dynamic request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request['nombre']} ${request['apellido']}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request['user_email'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(request['created_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(request['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Current and new photo
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const Text('Foto Actual'),
                        const SizedBox(height: 8),
                        _buildAvatar(request['avatar_image'], size: 100),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        const Text('Foto Nueva'),
                        const SizedBox(height: 8),
                        _buildAvatar(request['new_avatar_image'], size: 280),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final reason =
                          await _showRejectionReasonDialog(context);
                      if (reason != null) {
                        await _handleRequest(request['id'], 'rejected',
                            rejectionReason: reason);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Rechazar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _handleRequest(request['id'], 'approved');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Aprobar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? imageData, {double size = 80}) {
    if (imageData == null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Colors.white,
        ),
      );
    }

    // Si la imagen es base64
    if (imageData.startsWith('data:image')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: MemoryImage(
              base64Decode(imageData.split(',')[1]),
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Si la imagen es una URL
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: NetworkImage(imageData),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildNewAvatar(String? imageData) {
    if (imageData == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Icon(
          Icons.person,
          size: 80,
          color: Colors.white,
        ),
      );
    }

    // Si la imagen es base64
    if (imageData.startsWith('data:image')) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: MemoryImage(
              base64Decode(imageData.split(',')[1]),
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Si la imagen es una URL
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageData),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }
}
