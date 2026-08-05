import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/user_api.dart';

/// Ofertas de aliados dentro de una categoría — un item por (aliado, servicio),
/// ej: dentro de "Aseo de hogar": lavar baños de Juan, limpiar cocina de Pablo.
class CategoryOffersScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryOffersScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryOffersScreen> createState() => _CategoryOffersScreenState();
}

class _CategoryOffersScreenState extends State<CategoryOffersScreen> {
  List<Map<String, dynamic>> _ofertas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final ofertas = await CategoriaService.ofertas(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _ofertas = ofertas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _abrirDetalle(Map<String, dynamic> oferta, ThemeProvider themeProvider) {
    final fotos = (oferta['photos'] as List?)?.cast<String>() ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.cardBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              oferta['nombre_comercial'] ??
                  '${oferta['ally_nombre'] ?? ''} ${oferta['ally_apellido'] ?? ''}'.trim(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 4),
            Text(
              oferta['service_name'] ?? '',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF78BF32)),
            ),
            if ((oferta['frase_presentacion'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                '"${oferta['frase_presentacion']}"',
                style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: themeProvider.secondaryTextColor),
              ),
            ],
            if ((oferta['resumen'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text(oferta['resumen'],
                  style: TextStyle(fontSize: 15, height: 1.4, color: themeProvider.textColor)),
            ],
            if (fotos.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Trabajos anteriores',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
              const SizedBox(height: 10),
              GridView.builder(
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
                  child: Image.network(fotos[i], fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF78BF32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Contratar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        title: Text(widget.categoryName,
            style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.scaffoldBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF78BF32)))
          : _ofertas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Todavía no hay aliados ofreciendo servicios en esta categoría.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 15),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF78BF32),
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ofertas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final oferta = _ofertas[i];
                      final fotos = (oferta['photos'] as List?) ?? [];
                      final nombre = (oferta['nombre_comercial'] as String?)?.isNotEmpty == true
                          ? oferta['nombre_comercial']
                          : '${oferta['ally_nombre'] ?? ''} ${oferta['ally_apellido'] ?? ''}'.trim();

                      return Material(
                        color: themeProvider.cardBgColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _abrirDetalle(oferta, themeProvider),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: fotos.isNotEmpty
                                      ? Image.network(fotos.first,
                                          width: 56, height: 56, fit: BoxFit.cover)
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          color: const Color(0xFF78BF32).withOpacity(0.12),
                                          child: const Icon(Icons.person_outline,
                                              color: Color(0xFF78BF32)),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        oferta['service_name'] ?? '',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.textColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                            fontSize: 13, color: themeProvider.secondaryTextColor),
                                      ),
                                      if ((oferta['frase_presentacion'] as String?)?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          oferta['frase_presentacion'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: themeProvider.secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: themeProvider.secondaryTextColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
