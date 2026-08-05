import 'package:flutter/material.dart';

import '../config.dart';
import '../services/admin_api.dart';

/// Catálogo de servicios ya aprobados, agrupado por categoría — solo
/// visualización. El botón "+" deja al admin crear una categoría directo
/// (entra aprobada de una, sin pasar por revisión), para precargar el
/// catálogo antes de que ningún aliado la proponga.
class ServiciosCatalogoScreen extends StatefulWidget {
  const ServiciosCatalogoScreen({super.key});

  @override
  State<ServiciosCatalogoScreen> createState() => _ServiciosCatalogoScreenState();
}

class _ServiciosCatalogoScreenState extends State<ServiciosCatalogoScreen> {
  List<Map<String, dynamic>> _servicios = [];
  bool _cargando = true;
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
      final datos = await ServiciosAdminApi.listar(estado: 'approved');
      if (!mounted) return;
      setState(() {
        _servicios = datos;
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
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ej: Carpintería',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Config.primaryColor),
            onPressed: () {
              final texto = controlador.text.trim();
              if (texto.length < 2) return;
              Navigator.pop(ctx, texto);
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (nombre == null) return;

    try {
      await CategoriasAdminApi.crear(nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoría "$nombre" creada'), backgroundColor: Config.primaryColor),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la categoría'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.backgroundColor,
      appBar: AppBar(
        title: const Text('Servicios'),
        backgroundColor: Config.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nueva categoría',
            onPressed: _crearCategoria,
          ),
        ],
      ),
      body: _contenido(),
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

    if (_servicios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Todavía no hay servicios aprobados. Los aliados los proponen desde su perfil, o creá una categoría con el botón "+" para adelantarte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final porCategoria = <String, List<Map<String, dynamic>>>{};
    for (final s in _servicios) {
      final categoria = s['category'] as Map<String, dynamic>?;
      final nombre = categoria?['name'] ?? 'Sin categoría';
      (porCategoria[nombre] ??= []).add(s);
    }

    final categorias = porCategoria.keys.toList()..sort();

    return RefreshIndicator(
      color: Config.primaryColor,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categorias.length,
        itemBuilder: (_, i) {
          final nombreCategoria = categorias[i];
          final servicios = porCategoria[nombreCategoria]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreCategoria,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...servicios.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(s['name'] ?? ''),
                        subtitle: (s['description'] as String?)?.isNotEmpty == true
                            ? Text(s['description'])
                            : null,
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
