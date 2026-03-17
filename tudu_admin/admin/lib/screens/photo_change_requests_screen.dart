import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
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
      print('Nueva solicitud recibida: $data');
      // Actualizar la lista de solicitudes
      _loadRequests();
      // Mostrar notificación en la app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nueva solicitud de cambio de foto'),
          backgroundColor: Config.primaryColor,
          duration: Duration(seconds: 3),
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
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/api/admin/photo-change-requests'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _requests = data['data']
              .where((request) => request['status'] == 'pending')
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
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

  Future<void> _handleRequest(int id, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/api/admin/photo-change-requests/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved'
                ? 'Solicitud aprobada'
                : 'Solicitud rechazada'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        _loadRequests(); // Refresh the list
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['error'] ?? 'Error al procesar solicitud'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      onTap: () => _showRequestDetail(context, request),
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${request['nombre']} ${request['apellido']}',
                                      style: const TextStyle(
                                        fontSize: 18,
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
                  ElevatedButton(
                    onPressed: () async {
                      await _handleRequest(request['id'], 'rejected');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(150, 50),
                    ),
                    child: const Text(
                      'Rechazar',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _handleRequest(request['id'], 'approved');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(150, 50),
                    ),
                    child: const Text(
                      'Aprobar',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
