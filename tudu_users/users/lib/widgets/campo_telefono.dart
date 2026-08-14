import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';

/// Selector de país + número de teléfono.
///
/// El widget del paquete (`IntlPhoneField`) abre su lista en un `showDialog`
/// propio: hereda el tema de la app —de ahí el fondo mostaza— y no deja poner
/// el desenfoque que sí tienen los demás selectores de esta pantalla. Acá se
/// usa solo su catálogo de países (`countries`) y la hoja se dibuja a mano.
class CampoTelefono extends StatefulWidget {
  final TextEditingController controller;

  /// Código ISO del país (CO, MX...) con el que abre.
  final String isoInicial;

  /// Devuelve el país elegido, el número tal cual se escribió y el número
  /// completo con prefijo, que es lo que se guarda.
  final void Function(Country pais, String numero, String completo) onChanged;

  const CampoTelefono({
    super.key,
    required this.controller,
    required this.isoInicial,
    required this.onChanged,
  });

  @override
  State<CampoTelefono> createState() => _CampoTelefonoState();
}

class _CampoTelefonoState extends State<CampoTelefono> {
  static const Color _marca = Color(0xFF78BF32);

  late Country _pais;

  @override
  void initState() {
    super.initState();
    _pais = _porIso(widget.isoInicial);
  }

  @override
  void didUpdateWidget(CampoTelefono anterior) {
    super.didUpdateWidget(anterior);
    // El país llega después de la primera pintada: se resuelve consultando el
    // catálogo del backend con el prefijo guardado.
    if (anterior.isoInicial != widget.isoInicial) {
      _pais = _porIso(widget.isoInicial);
    }
  }

  Country _porIso(String iso) => countries.firstWhere(
        (c) => c.code == iso.toUpperCase(),
        orElse: () => countries.firstWhere((c) => c.code == 'CO'),
      );

  /// Nombre del país en el idioma de la app. El catálogo del paquete trae las
  /// traducciones; si falta la del idioma actual queda el nombre en inglés.
  String _nombre(Country pais, AppLocalizations loc) =>
      pais.nameTranslations[loc.locale.languageCode] ?? pais.name;

  /// La lista viene ordenada por el nombre en inglés. Mostrándola en español
  /// quedaba desordenada ("Afganistán, Islas Åland, Albania, Argelia"), así que
  /// se ordena por el nombre que se está viendo.
  List<Country> _ordenados(AppLocalizations loc) {
    final lista = [...countries];
    lista.sort((a, b) => _nombre(a, loc)
        .toLowerCase()
        .compareTo(_nombre(b, loc).toLowerCase()));
    return lista;
  }

  void _avisar() {
    final numero = widget.controller.text.trim();
    widget.onChanged(
      _pais,
      numero,
      numero.isEmpty ? '' : '+${_pais.dialCode}$numero',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SizedBox(
      height: 26,
      child: Row(
        children: [
          GestureDetector(
            onTap: _elegirPais,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_pais.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('+${_pais.dialCode}',
                    style: TextStyle(
                        fontSize: 16, color: themeProvider.textColor)),
                const Icon(Icons.arrow_drop_down, size: 20, color: _marca),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
              onChanged: (_) => _avisar(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _elegirPais() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    final buscador = TextEditingController();
    final oscuro = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final texto = buscador.text.trim().toLowerCase();
          final ordenados = _ordenados(loc);
          final lista = texto.isEmpty
              ? ordenados
              : ordenados
                  .where((c) =>
                      _nombre(c, loc).toLowerCase().contains(texto) ||
                      c.name.toLowerCase().contains(texto) ||
                      c.dialCode.contains(texto))
                  .toList();

          // Mismo desenfoque que los selectores de género y fecha de esta
          // pantalla: la lista no aparece pegada sobre un fondo plano.
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color:
                    oscuro ? const Color(0xFF1C1C1E) : const Color(0xFFF1F1EC),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: oscuro ? Colors.grey[600] : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: TextField(
                      controller: buscador,
                      autofocus: false,
                      cursorColor: _marca,
                      style: TextStyle(color: themeProvider.textColor),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: loc.t('search_country'),
                        hintStyle:
                            TextStyle(color: themeProvider.secondaryTextColor),
                        filled: true,
                        fillColor: themeProvider.cardBgColor,
                        suffixIcon: Icon(Icons.search,
                            color: themeProvider.secondaryTextColor),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _marca, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      // Debajo de la lista va el borde redondeado de la hoja y
                      // la barra de gestos del teléfono: sin esta holgura el
                      // último país queda cortado por la mitad.
                      padding: EdgeInsets.only(
                        bottom: 28 + MediaQuery.of(context).viewPadding.bottom,
                      ),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: (oscuro ? Colors.white : Colors.black)
                            .withOpacity(0.06),
                      ),
                      itemBuilder: (_, i) {
                        final pais = lista[i];
                        final elegido = pais.code == _pais.code;

                        return ListTile(
                          onTap: () {
                            setState(() => _pais = pais);
                            // El número anterior es de otro país: se limpia,
                            // igual que hacía el widget del paquete.
                            widget.controller.clear();
                            _avisar();
                            Navigator.pop(context);
                          },
                          leading: Text(pais.flag,
                              style: const TextStyle(fontSize: 22)),
                          title: Text(
                            _nombre(pais, loc),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  elegido ? FontWeight.bold : FontWeight.w600,
                              color: elegido
                                  ? _marca
                                  : themeProvider.textColor,
                            ),
                          ),
                          trailing: Text(
                            '+${pais.dialCode}',
                            style: TextStyle(
                                fontSize: 15,
                                color: themeProvider.secondaryTextColor),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
