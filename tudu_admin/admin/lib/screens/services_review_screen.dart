import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/admin_api.dart';

/// Revisión de categorías y servicios propuestos por los aliados.
///
/// Mismo patrón que `kyc_review_screen.dart`: la fila real vive en
/// `services`/`categories` con `review_status`, no en una tabla de
/// sugerencias aparte. Cada servicio que un aliado propone —el primero
/// obligatorio del onboarding y cualquiera después— pasa por acá.
class ServiciosReviewScreen extends StatefulWidget {
  const ServiciosReviewScreen({super.key});

  @override
  State<ServiciosReviewScreen> createState() => _ServiciosReviewScreenState();
}

class _ServiciosReviewScreenState extends State<ServiciosReviewScreen> {
  List<Map<String, dynamic>> _servicios = [];
  bool _cargando = true;
  String _estado = 'pending';
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
      final datos = await ServiciosAdminApi.listar(estado: _estado);
      if (!mounted) return;
      setState(() {
        _servicios = datos;
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

  Future<void> _abrirDetalle(Map<String, dynamic> servicio) async {
    final revisado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _DetalleServicioScreen(servicio: servicio)),
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
      'pending': 'Pendientes',
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

    if (_servicios.isEmpty) {
      return _mensajeCentral(
        Icons.miscellaneous_services_outlined,
        _estado == 'pending'
            ? 'No hay servicios pendientes de revisión'
            : 'No hay servicios en este estado',
        accion: 'Actualizar',
        onAccion: _cargar,
      );
    }

    return RefreshIndicator(
      color: Config.primaryColor,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _servicios.length,
        itemBuilder: (_, i) => _tarjeta(_servicios[i]),
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

  Widget _tarjeta(Map<String, dynamic> s) {
    final estado = s['review_status'] ?? 'pending';
    final sinRevisar = estado == 'pending';
    final categoria = s['category'] as Map<String, dynamic>?;
    final aliado = s['allies'] as Map<String, dynamic>?;
    final fotos = (s['portfolio'] as List?) ?? [];

    return GestureDetector(
      onTap: () => _abrirDetalle(s),
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
              if (sinRevisar)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['name'] ?? '',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: sinRevisar ? FontWeight.bold : FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoria != null
                          ? '${categoria['name']}'
                              '${categoria['review_status'] != 'approved' ? ' (nueva)' : ''}'
                          : 'Sin categoría',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    if (aliado != null)
                      Text(
                        '${aliado['nombre'] ?? ''} ${aliado['apellido'] ?? ''} · ${aliado['email'] ?? ''}'
                            .trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (fotos.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${fotos.length} foto(s)',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
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

  static Widget _etiquetaEstado(String estado) {
    late final Color color;
    late final String texto;

    switch (estado) {
      case 'approved':
        color = Colors.green;
        texto = 'Aprobado';
        break;
      case 'rejected':
        color = Colors.red;
        texto = 'Rechazado';
        break;
      default:
        color = Colors.orange;
        texto = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(texto,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

/// Detalle de un servicio propuesto: categoría (con opción de redirigir),
/// nombre/descripción editables, pruebas y la decisión final.
class _DetalleServicioScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;

  const _DetalleServicioScreen({required this.servicio});

  @override
  State<_DetalleServicioScreen> createState() => _DetalleServicioScreenState();
}

class _DetalleServicioScreenState extends State<_DetalleServicioScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  final TextEditingController _buscarCategoriaController = TextEditingController();

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _categoriasFiltradas = [];
  Map<String, dynamic>? _categoriaElegida;
  bool _redirigiendoCategoria = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.servicio['name'] ?? '');
    _descripcionController =
        TextEditingController(text: widget.servicio['description'] ?? '');
    _buscarCategoriaController.addListener(_filtrarCategorias);
    _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _buscarCategoriaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await CategoriasAdminApi.listar();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _categoriasFiltradas = categorias;
      });
    } catch (_) {}
  }

  void _filtrarCategorias() {
    final q = _buscarCategoriaController.text.toLowerCase().trim();
    setState(() {
      _categoriasFiltradas = q.isEmpty
          ? _categorias
          : _categorias.where((c) => (c['name'] as String).toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _revisar(String estado) async {
    String? motivo;

    if (estado == 'rejected') {
      motivo = await _pedirMotivo();
      if (motivo == null) return;
    }

    setState(() => _enviando = true);

    try {
      await ServiciosAdminApi.revisar(
        widget.servicio['id'],
        estado,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoryId: _categoriaElegida?['id'],
        motivo: motivo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(estado == 'approved' ? 'Servicio aprobado' : 'Servicio rechazado'),
          backgroundColor: estado == 'approved' ? Colors.green : Colors.red,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la revisión'), backgroundColor: Colors.red),
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
              'El aliado verá este mensaje: fotos inapropiadas, contenido generado con IA, texto ofensivo, etc.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controlador,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: las fotos parecen generadas con IA',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final texto = controlador.text.trim();
              if (texto.isEmpty) return;
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
    final s = widget.servicio;
    final categoria = s['category'] as Map<String, dynamic>?;
    final aliado = s['allies'] as Map<String, dynamic>?;
    final fotos = (s['portfolio'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final categoriaPendiente = categoria == null || categoria['review_status'] != 'approved';

    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Servicio propuesto'),
        backgroundColor: Config.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (aliado != null) _bloqueAliado(aliado),
          const SizedBox(height: 16),
          _bloqueCategoria(categoria, categoriaPendiente),
          const SizedBox(height: 16),
          const Text('Nombre y descripción',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Podés corregir la ortografía antes de aprobar.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descripcionController,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Text('Pruebas (${fotos.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          fotos.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                      child: Text('El aliado no subió fotos', style: TextStyle(color: Colors.black45))),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _verGrande(fotos[i]['image_path']),
                      child: Image.network(
                        fotos[i]['image_path'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
          if (s['admin_note'] != null) ...[
            const SizedBox(height: 16),
            _notaRevision(s['admin_note']),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: (s['review_status'] ?? 'pending') != 'pending'
          ? null
          : SafeArea(
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : () => _revisar('approved'),
                        icon: _enviando
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label: const Text('Aprobar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(150, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _bloqueAliado(Map<String, dynamic> aliado) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${aliado['nombre'] ?? ''} ${aliado['apellido'] ?? ''}'.trim(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(aliado['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _bloqueCategoria(Map<String, dynamic>? categoria, bool pendiente) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Categoría', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (pendiente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Propuesta nueva',
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _categoriaElegida != null
                  ? '→ ${_categoriaElegida!['name']}'
                  : (categoria?['name'] ?? 'Sin categoría'),
              style: const TextStyle(fontSize: 15),
            ),
            if (pendiente) ...[
              const SizedBox(height: 10),
              if (!_redirigiendoCategoria)
                TextButton.icon(
                  onPressed: () => setState(() => _redirigiendoCategoria = true),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Esto ya existe con otro nombre — redirigir'),
                )
              else ...[
                TextField(
                  controller: _buscarCategoriaController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar categoría existente...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _categoriasFiltradas.length,
                    itemBuilder: (_, i) {
                      final c = _categoriasFiltradas[i];
                      return ListTile(
                        dense: true,
                        title: Text(c['name']),
                        onTap: () => setState(() {
                          _categoriaElegida = c;
                          _redirigiendoCategoria = false;
                        }),
                      );
                    },
                  ),
                ),
                if (_categoriaElegida != null)
                  TextButton(
                    onPressed: () => setState(() => _categoriaElegida = null),
                    child: const Text('Cancelar redirección'),
                  ),
              ],
            ],
          ],
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
          const Text('Nota de revisión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(nota, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _verGrande(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
