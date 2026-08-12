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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _DetalleServicioScreen(servicio: servicio)),
    );

    // Siempre se recarga: en el detalle se puede haber decidido el servicio, la
    // categoría o borrado una prueba, y salir con gesto no devuelve resultado.
    if (mounted) _cargar();
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

/// Lo que devuelve el diálogo de rechazo: el motivo escrito y los campos que
/// el admin marcó para corregir.
class _Rechazo {
  final String motivo;
  final List<String> campos;

  const _Rechazo(this.motivo, this.campos);
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

  /// Copias mutables: la categoría se puede aprobar sin salir de la pantalla y
  /// las pruebas se pueden borrar de a una, así que no se puede leer siempre
  /// del mapa que llegó por parámetro.
  Map<String, dynamic>? _categoria;
  List<Map<String, dynamic>> _fotos = [];
  bool _revisandoCategoria = false;

  /// La categoría con la que el servicio quedaría al aprobarlo: la redirigida
  /// si el admin eligió otra, si no la que propuso el aliado.
  Map<String, dynamic>? get _categoriaFinal => _categoriaElegida ?? _categoria;

  bool get _categoriaResuelta => _categoriaFinal?['review_status'] == 'approved';

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.servicio['name'] ?? '');
    _descripcionController =
        TextEditingController(text: widget.servicio['description'] ?? '');
    _categoria = widget.servicio['category'] as Map<String, dynamic>?;
    _fotos = ((widget.servicio['portfolio'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .toList();
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

  /// Aprueba o rechaza la categoría que propuso el aliado, sin tocar el
  /// servicio: son dos decisiones separadas ("la categoría sirve, el servicio
  /// no" es un caso normal).
  Future<void> _revisarCategoria(String estado) async {
    final categoria = _categoria;
    if (categoria == null) return;

    String? motivo;
    if (estado == 'rejected') {
      motivo = await _pedirMotivo(
        titulo: 'Motivo del rechazo de la categoría',
        ayuda: 'El aliado verá este mensaje. Si la categoría ya existe con otro '
            'nombre, mejor usá "redirigir" en vez de rechazarla.',
      );
      if (motivo == null) return;
    }

    setState(() => _revisandoCategoria = true);

    try {
      await CategoriasAdminApi.revisar(
        categoria['id'],
        estado,
        nombre: categoria['name'],
        motivo: motivo,
      );

      if (!mounted) return;
      setState(() {
        _categoria = {...categoria, 'review_status': estado};
        _revisandoCategoria = false;
      });
      _avisar(
        estado == 'approved' ? 'Categoría aprobada' : 'Categoría rechazada',
        esError: estado != 'approved',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revisandoCategoria = false);
      _avisar(e is ApiException ? e.message : 'No se pudo revisar la categoría',
          esError: true);
    }
  }

  /// Borra una prueba puntual. Evita rechazar un servicio entero por una sola
  /// foto que no corresponde.
  Future<void> _borrarFoto(Map<String, dynamic> foto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Borrar esta prueba?'),
        content: const Text(
          'Se borra del portafolio del aliado y del almacenamiento. No se puede deshacer.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await ServiciosAdminApi.borrarFoto(foto['id']);
      if (!mounted) return;
      setState(() => _fotos.removeWhere((f) => f['id'] == foto['id']));
      _avisar('Prueba borrada');
    } catch (e) {
      if (!mounted) return;
      _avisar(e is ApiException ? e.message : 'No se pudo borrar la foto', esError: true);
    }
  }

  Future<void> _revisar(String estado) async {
    // El backend rechaza aprobar un servicio con la categoría sin resolver
    // (quedaría invisible para los usuarios); acá se avisa antes de gastar el
    // viaje, explicando las dos salidas.
    if (estado == 'approved' && !_categoriaResuelta) {
      _avisar(
        'Primero resolvé la categoría: aprobala o redirigí el servicio a una existente.',
        esError: true,
      );
      return;
    }

    String? motivo;
    List<String>? campos;

    if (estado == 'rejected') {
      final rechazo = await _pedirRechazo();
      if (rechazo == null) return;
      motivo = rechazo.motivo;
      campos = rechazo.campos;
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
        campos: campos,
      );

      // Redirigir deja la categoría propuesta sin usar: si no se resuelve acá,
      // se queda pendiente para siempre en la cola del admin.
      final propuesta = _categoria;
      if (_categoriaElegida != null &&
          propuesta != null &&
          propuesta['review_status'] != 'approved' &&
          propuesta['id'] != _categoriaElegida!['id']) {
        try {
          await CategoriasAdminApi.revisar(
            propuesta['id'],
            'rejected',
            nombre: propuesta['name'],
            motivo: 'Ya existe como "${_categoriaElegida!['name']}" — '
                'el servicio se movió a esa categoría.',
          );
        } catch (_) {
          // La decisión del servicio ya quedó guardada: que falle el descarte de
          // la categoría no debe deshacerla ni bloquear al admin.
        }
      }

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

  void _avisar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: esError ? Colors.red : Colors.green,
    ));
  }

  /// Rechazo de un servicio: motivo en prosa + los campos concretos a corregir.
  /// Sin los campos el aliado lee "las fotos no corresponden" y no sabe si
  /// tiene que rehacer también el nombre o la descripción.
  Future<_Rechazo?> _pedirRechazo() {
    final controlador = TextEditingController();
    final seleccionados = <String>{};

    const campos = {
      'name': 'Nombre',
      'description': 'Descripción',
      'portfolio': 'Fotos de prueba',
      'category': 'Categoría',
    };

    return showDialog<_Rechazo>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rechazar servicio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Qué tiene que corregir el aliado?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: campos.entries.map((c) {
                    final activo = seleccionados.contains(c.key);
                    return FilterChip(
                      label: Text(c.value, style: const TextStyle(fontSize: 12)),
                      selected: activo,
                      selectedColor: Config.primaryColor.withOpacity(0.25),
                      checkmarkColor: Colors.black87,
                      onSelected: (_) => setStateDialog(() {
                        activo ? seleccionados.remove(c.key) : seleccionados.add(c.key);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'El aliado verá este mensaje y los campos marcados, y podrá corregir y reenviar.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final texto = controlador.text.trim();
                if (texto.isEmpty || seleccionados.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Marcá al menos un campo y escribí el motivo'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(ctx, _Rechazo(texto, seleccionados.toList()));
              },
              child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pedirMotivo({
    String titulo = 'Motivo del rechazo',
    String ayuda =
        'El aliado verá este mensaje: fotos inapropiadas, contenido generado con IA, texto ofensivo, etc.',
  }) {
    final controlador = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ayuda,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
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
    final aliado = s['allies'] as Map<String, dynamic>?;
    final fotos = _fotos;
    final categoriaPendiente = !_categoriaResuelta;

    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Servicio propuesto'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (aliado != null) _bloqueAliado(aliado),
          const SizedBox(height: 16),
          _bloqueCategoria(_categoria, categoriaPendiente),
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
          const SizedBox(height: 4),
          const Text(
            'Tocá una para verla grande. La ✕ la borra sin rechazar el servicio entero.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
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
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
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
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _borrarFoto(fotos[i]),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
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
                _insigniaCategoria(categoria),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _categoriaElegida != null
                  ? '${categoria?['name'] ?? 'Sin categoría'}  →  ${_categoriaElegida!['name']}'
                  : (categoria?['name'] ?? 'Sin categoría'),
              style: const TextStyle(fontSize: 15),
            ),
            if (_categoriaElegida != null) ...[
              const SizedBox(height: 6),
              Text(
                'Al guardar, el servicio queda en "${_categoriaElegida!['name']}" y '
                '"${categoria?['name'] ?? ''}" se descarta como duplicada.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            // El aliado propuso una categoría que no existía: hay que decidirla
            // antes de aprobar el servicio, o el servicio queda invisible para
            // los usuarios (`GET /categories` solo devuelve las aprobadas).
            if (pendiente && _categoriaElegida == null && categoria != null) ...[
              const SizedBox(height: 4),
              const Text(
                'Decidila antes de aprobar el servicio: aprobala si es una categoría '
                'que falta en el catálogo, o redirigí el servicio si ya existe con otro nombre.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              if (_revisandoCategoria)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Config.primaryColor),
                  ),
                )
              else if (categoria['review_status'] == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _revisarCategoria('approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Aprobar categoría'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _revisarCategoria('rejected'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Categoría rechazada: el servicio no se puede aprobar acá. '
                    'Redirigilo a una categoría existente o rechazalo también.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
            ],
            // Se sigue mostrando con la redirección ya elegida: si no, aceptar
            // una categoría existente escondería el botón de deshacerla.
            if (pendiente || _categoriaElegida != null) ...[
              const SizedBox(height: 10),
              if (!_redirigiendoCategoria)
                TextButton.icon(
                  onPressed: () => setState(() => _redirigiendoCategoria = true),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(_categoriaElegida != null
                      ? 'Elegir otra categoría'
                      : 'Esto ya existe con otro nombre — redirigir'),
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

  /// Estado de la categoría en el momento: propuesta por el aliado, ya aprobada
  /// (existía o la acaba de aprobar el admin) o rechazada.
  static Widget _insigniaCategoria(Map<String, dynamic>? categoria) {
    late final Color color;
    late final String texto;

    switch (categoria?['review_status']) {
      case 'approved':
        color = Colors.green;
        texto = 'Del catálogo';
        break;
      case 'rejected':
        color = Colors.red;
        texto = 'Rechazada';
        break;
      default:
        color = Colors.orange;
        texto = 'Propuesta nueva';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(texto,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
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
