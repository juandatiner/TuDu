import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';

import '../l10n/app_localizations.dart';
import 'campo_caja.dart';

/// Teléfono con selector de país.
///
/// El widget del paquete (`IntlPhoneField`) abre su lista en un `showDialog`
/// propio: hereda el tema de la app y no deja tocar ni el fondo ni la barrera,
/// así que la lista salía con separadores negros y sin el desenfoque que usan
/// los demás selectores de la app. Acá se usa solo su catálogo de países
/// (`countries`) y la hoja se dibuja a mano.
class CampoTelefono extends StatefulWidget {
  final TextEditingController controller;

  /// Código ISO del país (CO, MX...) con el que abre.
  final String isoInicial;

  final String? error;

  /// Devuelve el país elegido, el número tal cual se escribió y el número
  /// completo con prefijo, que es lo que se guarda.
  final void Function(Country pais, String numero, String completo) onChanged;

  const CampoTelefono({
    super.key,
    required this.controller,
    required this.isoInicial,
    required this.onChanged,
    this.error,
  });

  @override
  State<CampoTelefono> createState() => _CampoTelefonoState();
}

class _CampoTelefonoState extends State<CampoTelefono> {
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
  String _nombre(Country pais) =>
      pais.nameTranslations[context.loc.locale.languageCode] ?? pais.name;

  /// La lista viene ordenada por el nombre en inglés. Mostrándola en español
  /// quedaba desordenada ("Afganistán, Islas Åland, Albania, Argelia"), así que
  /// se ordena por el nombre que se está viendo.
  List<Country> _ordenados() {
    final lista = [...countries];
    lista.sort((a, b) =>
        _nombre(a).toLowerCase().compareTo(_nombre(b).toLowerCase()));
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
    return CampoCaja(
      icono: Icons.phone_outlined,
      etiqueta: context.tr('phone'),
      hayError: widget.error != null,
      hijo: SizedBox(
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
                      style: const TextStyle(fontSize: 16, color: Colors.black)),
                  const Icon(Icons.arrow_drop_down,
                      size: 20, color: CampoColores.marca),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 16, color: Colors.black),
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
      ),
    );
  }

  void _elegirPais() {
    final buscador = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final texto = buscador.text.trim().toLowerCase();
          final ordenados = _ordenados();
          final lista = texto.isEmpty
              ? ordenados
              : ordenados
                  .where((c) =>
                      _nombre(c).toLowerCase().contains(texto) ||
                      c.name.toLowerCase().contains(texto) ||
                      c.dialCode.contains(texto))
                  .toList();

          // Mismo desenfoque que los otros selectores de la app: la pantalla de
          // atrás se sigue viendo, pero no compite con la lista.
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1EC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: TextField(
                      controller: buscador,
                      autofocus: false,
                      cursorColor: CampoColores.marca,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: context.tr('search_country'),
                        hintStyle: const TextStyle(
                            color: CampoColores.textoSecundario),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.search,
                            color: CampoColores.textoSecundario),
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
                          borderSide: const BorderSide(
                              color: CampoColores.marca, width: 1.5),
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
                        color: Colors.black.withOpacity(0.06),
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
                            _nombre(pais),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: elegido
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: elegido
                                  ? CampoColores.marca
                                  : Colors.black87,
                            ),
                          ),
                          trailing: Text(
                            '+${pais.dialCode}',
                            style: const TextStyle(
                                fontSize: 15,
                                color: CampoColores.textoSecundario),
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
