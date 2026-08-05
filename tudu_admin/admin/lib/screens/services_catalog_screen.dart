import 'package:flutter/material.dart';

import '../config.dart';
import '../services/admin_api.dart';

/// Catálogo de servicios ya aprobados, agrupado por categoría — solo
/// visualización. El título se divide en "Panel de Administración" / "Nuevo"
/// (mismo patrón que Usuarios/Aliados): "Nuevo" muestra el formulario para
/// crear una categoría directo (entra aprobada de una, sin pasar por
/// revisión), para precargar el catálogo antes de que ningún aliado la
/// proponga.
class ServiciosCatalogoScreen extends StatefulWidget {
  const ServiciosCatalogoScreen({super.key});

  @override
  State<ServiciosCatalogoScreen> createState() => _ServiciosCatalogoScreenState();
}

class _ServiciosCatalogoScreenState extends State<ServiciosCatalogoScreen> {
  List<Map<String, dynamic>> _servicios = [];
  // Todas las categorías aprobadas — el grid las muestra todas, tengan o no
  // servicios todavía (una recién creada por el admin arranca en 0).
  List<Map<String, dynamic>> _categorias = [];
  bool _cargando = true;
  String? _error;

  // 0 = catálogo (panel), 1 = formulario de nueva categoría.
  int _vista = 0;
  final TextEditingController _nuevaCategoriaController = TextEditingController();
  bool _creandoCategoria = false;
  String? _errorNuevaCategoria;

  // El campo de "Nueva categoría" busca primero entre las existentes (mismo
  // `_categorias` de arriba) — el botón de crear solo se habilita si la
  // búsqueda no encuentra nada, para no terminar con categorías duplicadas.
  List<Map<String, dynamic>> _categoriasFiltradas = [];

  // Buscador del catálogo (panel) — filtra las cajas de categoría por nombre.
  final TextEditingController _buscadorController = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _buscadorController.addListener(() {
      setState(() => _busqueda = _buscadorController.text.toLowerCase().trim());
    });
    _cargar();
    _nuevaCategoriaController.addListener(_filtrarCategorias);
  }

  @override
  void dispose() {
    _nuevaCategoriaController.dispose();
    _buscadorController.dispose();
    super.dispose();
  }

  void _filtrarCategorias() {
    final query = _nuevaCategoriaController.text.toLowerCase().trim();
    setState(() {
      _errorNuevaCategoria = null;
      _categoriasFiltradas = query.isEmpty
          ? []
          : _categorias
              .where((c) => (c['name'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ServiciosAdminApi.listar(estado: 'approved'),
        CategoriasAdminApi.listar(),
      ]);
      if (!mounted) return;
      setState(() {
        _servicios = resultados[0];
        _categorias = resultados[1];
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

  Future<void> _crearCategoria() async {
    final nombre = _nuevaCategoriaController.text.trim();
    if (nombre.length < 2) {
      setState(() => _errorNuevaCategoria = 'Mínimo 2 caracteres');
      return;
    }

    setState(() {
      _creandoCategoria = true;
      _errorNuevaCategoria = null;
    });
    try {
      await CategoriasAdminApi.crear(nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoría "$nombre" creada'), backgroundColor: Config.primaryColor),
      );
      _nuevaCategoriaController.clear();
      setState(() {
        _vista = 0;
        _categoriasFiltradas = [];
      });
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la categoría'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creandoCategoria = false);
    }
  }

  /// Título dividido en dos mitades clicables, mismo patrón que
  /// Usuarios/Aliados en el dashboard: tamaño de título fijo, separadas por
  /// una línea vertical.
  Widget _tituloDividido() {
    const estiloTitulo = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
    const opciones = ['Panel de Administración', 'Nuevo'];

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
              onTap: () => setState(() => _vista = i),
              child: Text(
                opciones[i],
                style: estiloTitulo.copyWith(
                  color: _vista == i ? Colors.black : Colors.black38,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(title: _tituloDividido()),
      body: _vista == 1 ? _formularioNuevaCategoria() : _contenido(),
    );
  }

  Widget _formularioNuevaCategoria() {
    final query = _nuevaCategoriaController.text.trim();
    final hayCoincidencias = _categoriasFiltradas.isNotEmpty;
    final puedeCrear = query.length >= 2 && !hayCoincidencias;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nueva categoría',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Busca primero para no repetir una que ya existe.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nuevaCategoriaController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Buscar o crear categoría',
              hintText: 'Ej: Carpintería',
              errorText: _errorNuevaCategoria,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (hayCoincidencias) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _categoriasFiltradas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.category, color: Config.primaryColor, size: 20),
                  title: Text(_categoriasFiltradas[i]['name'] ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ya existe una categoría así — no hace falta crear otra.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
            ),
          ] else if (puedeCrear)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creandoCategoria ? null : _crearCategoria,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: _creandoCategoria
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Crear "$query"',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            )
          else
            Text(
              'Escribe al menos 2 letras para buscar.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Config.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_categorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Todavía no hay categorías. Los aliados las proponen desde su perfil, o creá una desde "Nuevo" para adelantarte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Todas las categorías aprobadas entran al grid, tengan o no servicios
    // todavía — una recién creada por el admin arranca en 0 y eso es normal.
    final porCategoria = <String, List<Map<String, dynamic>>>{
      for (final c in _categorias) c['name']: <Map<String, dynamic>>[],
    };
    for (final s in _servicios) {
      final categoria = s['category'] as Map<String, dynamic>?;
      final nombre = categoria?['name'] ?? 'Sin categoría';
      (porCategoria[nombre] ??= []).add(s);
    }

    // Con servicios primero (alfabético), sin servicios al final (alfabético).
    var categorias = porCategoria.keys.toList()
      ..sort((a, b) {
        final tieneA = porCategoria[a]!.isNotEmpty;
        final tieneB = porCategoria[b]!.isNotEmpty;
        if (tieneA != tieneB) return tieneA ? -1 : 1;
        return a.compareTo(b);
      });

    if (_busqueda.isNotEmpty) {
      categorias = categorias.where((c) => c.toLowerCase().contains(_busqueda)).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _buscadorController,
            decoration: InputDecoration(
              hintText: 'Buscar categoría...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: categorias.isEmpty
              ? Center(
                  child: Text(
                    'Ninguna categoría coincide con "$_busqueda"',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  color: Config.primaryColor,
                  onRefresh: _cargar,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 6 : 3;
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: categorias.length,
                        itemBuilder: (_, i) {
                          final nombreCategoria = categorias[i];
                          final servicios = porCategoria[nombreCategoria]!;
                          return _CategoriaBox(
                            nombre: nombreCategoria,
                            cantidad: servicios.length,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _ServiciosDeCategoriaScreen(
                                  categoria: nombreCategoria,
                                  servicios: servicios,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Caja de categoría — mismo lenguaje visual que las tarjetas del dashboard
/// (icono en caja de color + título en negrita), con la cantidad de
/// servicios como badge.
class _CategoriaBox extends StatelessWidget {
  final String nombre;
  final int cantidad;
  final VoidCallback onTap;

  const _CategoriaBox({
    required this.nombre,
    required this.cantidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Gris si la categoría todavía no tiene servicios, verde si ya tiene.
    final color = cantidad > 0 ? Config.primaryColor : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.category, size: 26, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nombre,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$cantidad',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de servicios de una categoría — cada uno muestra el nombre del
/// servicio y el aliado que lo presta (join `allies` que ya trae
/// `/api/admin/services`).
class _ServiciosDeCategoriaScreen extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> servicios;

  const _ServiciosDeCategoriaScreen({
    required this.categoria,
    required this.servicios,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(title: Text(categoria)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: servicios.length,
        itemBuilder: (_, i) {
          final s = servicios[i];
          final aliado = s['allies'] as Map<String, dynamic>?;
          final nombreAliado = aliado != null
              ? '${aliado['nombre'] ?? ''} ${aliado['apellido'] ?? ''}'.trim()
              : '';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Config.primaryColor.withOpacity(0.15),
                child: const Icon(Icons.build, color: Config.primaryColor),
              ),
              title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                nombreAliado.isNotEmpty ? 'Ofrecido por $nombreAliado' : 'Aliado no disponible',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        },
      ),
    );
  }
}
