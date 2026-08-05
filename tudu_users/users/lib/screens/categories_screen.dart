import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/user_api.dart';
import 'category_offers_screen.dart';

/// Solo categorías con al menos un servicio aprobado — coincide con lo que
/// ya filtra el backend en `GET /categories`.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final categorias = await CategoriaService.listar();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        title: Text('Categorías',
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
          : _categorias.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Todavía no hay categorías con servicios disponibles.',
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
                    itemCount: _categorias.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final categoria = _categorias[i];
                      return Material(
                        color: themeProvider.cardBgColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryOffersScreen(
                                categoryId: categoria['id'],
                                categoryName: categoria['name'],
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF78BF32).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.category_outlined, color: Color(0xFF78BF32)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    categoria['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.textColor,
                                    ),
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
