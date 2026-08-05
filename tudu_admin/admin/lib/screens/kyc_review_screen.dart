import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/admin_api.dart';

/// Revisión de la verificación de identidad de los aliados.
///
/// Antes no existía: un aliado subía su cédula, quedaba en `submitted` y ahí se
/// quedaba para siempre, porque no había forma de aprobarlo salvo editar la
/// fila a mano en Supabase.
class KycReviewScreen extends StatefulWidget {
  const KycReviewScreen({super.key});

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends State<KycReviewScreen> {
  List<Map<String, dynamic>> _aliados = [];
  bool _cargando = true;
  String _estado = 'submitted';
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await KycAdminApi.listar(estado: _estado);
      if (!mounted) return;
      setState(() {
        _aliados = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _cargando = false;
      });
    }
  }

  Future<void> _abrirDetalle(String email) async {
    final revisado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _DetalleKycScreen(email: email)),
    );

    if (revisado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _selectorEstado(),
        Expanded(child: _contenido()),
      ],
    );
  }

  Widget _selectorEstado() {
    const opciones = {
      'submitted': 'Pendientes',
      'approved': 'Aprobados',
      'rejected': 'Rechazados',
      'todos': 'Todos',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: opciones.entries.map((o) {
          final activo = _estado == o.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.value),
              selected: activo,
              onSelected: (_) {
                setState(() => _estado = o.key);
                _cargar();
              },
              selectedColor: Config.primaryColor,
              labelStyle: TextStyle(
                color: activo ? Colors.white : Colors.black87,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Config.primaryColor));
    }

    if (_error != null) {
      return _mensajeCentral(Icons.cloud_off, _error!, accion: 'Reintentar', onAccion: _cargar);
    }

    if (_aliados.isEmpty) {
      return _mensajeCentral(
        Icons.verified_user_outlined,
        _estado == 'submitted'
            ? 'No hay verificaciones pendientes'
            : 'No hay aliados en este estado',
        accion: 'Actualizar',
        onAccion: _cargar,
      );
    }

    return RefreshIndicator(
      color: Config.primaryColor,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _aliados.length,
        itemBuilder: (_, i) => _tarjeta(_aliados[i]),
      ),
    );
  }

  Widget _mensajeCentral(IconData icono, String texto,
      {String? accion, VoidCallback? onAccion}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 72, color: Colors.black26),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          if (accion != null) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: onAccion, child: Text(accion)),
          ],
        ],
      ),
    );
  }

  /// Misma tarjeta que las solicitudes de cambio de foto: borde rojo y punto
  /// mientras está sin revisar, nombre / correo / fecha a la izquierda y la
  /// etiqueta de estado en píldora de color sólido a la derecha.
  Widget _tarjeta(Map<String, dynamic> a) {
    final estado = a['kyc_status'] ?? 'pending';
    final sinRevisar = estado == 'submitted';

    return GestureDetector(
      onTap: () => _abrirDetalle(a['email']),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: sinRevisar ? Colors.red.withOpacity(0.6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Indicador de pendiente
              if (sinRevisar)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['nombre'] ?? ''} ${a['apellido'] ?? ''}'.trim(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            sinRevisar ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a['email'] ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fechaCorta(a['kyc_submitted_at'] ?? a['created_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _etiquetaEstado(estado),
            ],
          ),
        ),
      ),
    );
  }

  static String _fechaCorta(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '';
    final l = d.toLocal();
    final dia = l.day.toString().padLeft(2, '0');
    final mes = l.month.toString().padLeft(2, '0');
    final hora = l.hour.toString().padLeft(2, '0');
    final min = l.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${l.year} $hora:$min';
  }

  static Widget _etiquetaEstado(String estado) {
    late final Color color;
    late final String texto;

    switch (estado) {
      case 'approved':
        color = Colors.green;
        texto = 'Aprobada';
        break;
      case 'rejected':
        color = Colors.red;
        texto = 'Rechazada';
        break;
      case 'submitted':
        color = Colors.orange;
        texto = 'Pendiente';
        break;
      default:
        color = Colors.grey;
        texto = 'Sin documentos';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Detalle de un aliado: sus tres documentos y los botones de decisión.
class _DetalleKycScreen extends StatefulWidget {
  final String email;

  const _DetalleKycScreen({required this.email});

  @override
  State<_DetalleKycScreen> createState() => _DetalleKycScreenState();
}

class _DetalleKycScreenState extends State<_DetalleKycScreen> {
  Map<String, dynamic>? _aliado;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await KycAdminApi.detalle(widget.email);
      if (!mounted) return;
      setState(() {
        _aliado = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _revisar(String estado) async {
    String? motivo;

    // El motivo solo se pide al rechazar: es lo que verá el aliado para saber
    // qué corregir antes de volver a intentarlo.
    if (estado == 'rejected') {
      motivo = await _pedirMotivo();
      if (motivo == null) return; // canceló
    }

    setState(() => _enviando = true);

    try {
      await KycAdminApi.revisar(widget.email, estado, motivo: motivo);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(estado == 'approved'
              ? 'Aliado aprobado'
              : 'Verificación rechazada'),
          backgroundColor: estado == 'approved' ? Colors.green : Colors.red,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la revisión'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _pedirMotivo() {
    final controlador = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Motivo del rechazo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El aliado verá este mensaje para saber qué debe corregir.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controlador,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: la foto de la cédula está borrosa',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final texto = controlador.text.trim();
              if (texto.isEmpty) return; // el backend también lo exige
              Navigator.pop(ctx, texto);
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Verificación de identidad'),
      ),
      body: _cuerpo(),
      bottomNavigationBar: _barraDecision(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Config.primaryColor));
    }

    if (_error != null || _aliado == null) {
      return Center(child: Text(_error ?? 'No se encontró el aliado'));
    }

    final a = _aliado!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bloqueDatos(a),
        const SizedBox(height: 20),
        const Text('Documentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _documento('Cédula — frente', a['cedula_frente']),
        _documento('Cédula — reverso', a['cedula_reverso']),
        _documento('Selfie', a['selfie']),
        if (a['kyc_reviewer_note'] != null) ...[
          const SizedBox(height: 16),
          _notaRevision(a['kyc_reviewer_note']),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bloqueDatos(Map<String, dynamic> a) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${a['nombre'] ?? ''} ${a['apellido'] ?? ''}'.trim(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _fila('Correo', a['email']),
            _fila('Nacimiento', a['fecha_nacimiento']),
            _fila('Teléfono', a['phone']),
            _fila('Enviado', _fecha(a['kyc_submitted_at'])),
            _fila('Revisado', _fecha(a['kyc_reviewed_at'])),
            const SizedBox(height: 10),
            _KycReviewScreenState._etiquetaEstado(a['kyc_status'] ?? 'pending'),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, dynamic valor) {
    if (valor == null || valor.toString().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(etiqueta,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(valor.toString(), style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  static String? _fecha(dynamic iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return iso.toString();
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  /// Muestra el documento venga como URL firmada (Storage) o como base64
  /// (filas anteriores a la migración).
  Widget _documento(String titulo, dynamic valor) {
    final texto = valor?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 220,
              color: Colors.black12,
              child: texto.isEmpty
                  ? const Center(
                      child: Text('Sin documento',
                          style: TextStyle(color: Colors.black45)))
                  : _imagen(texto),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagen(String valor) {
    if (valor.startsWith('http')) {
      return InkWell(
        onTap: () => _verGrande(valor),
        child: Image.network(
          valor,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Text('No se pudo cargar', style: TextStyle(color: Colors.black45)),
          ),
          loadingBuilder: (_, hijo, progreso) => progreso == null
              ? hijo
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    // Formato antiguo: base64 dentro de la columna.
    final bytes = _base64(valor);
    if (bytes == null) {
      return const Center(
        child: Text('Formato no reconocido', style: TextStyle(color: Colors.black45)),
      );
    }

    return InkWell(
      onTap: () => _verGrande(valor),
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }

  static Uint8List? _base64(String valor) {
    try {
      final limpio = valor.contains(',') ? valor.split(',').last : valor;
      return base64Decode(limpio);
    } catch (_) {
      return null;
    }
  }

  void _verGrande(String valor) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          maxScale: 5,
          child: valor.startsWith('http')
              ? Image.network(valor, fit: BoxFit.contain)
              : Image.memory(_base64(valor) ?? Uint8List(0), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _notaRevision(String nota) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nota de revisión',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(nota, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  /// Los botones solo aparecen si hay algo que decidir.
  Widget? _barraDecision() {
    if (_cargando || _aliado == null) return null;
    if (_aliado!['kyc_status'] != 'submitted') return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : () => _revisar('rejected'),
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text('Rechazar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : () => _revisar('approved'),
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: const Text('Aprobar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
