import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';

/// Cuánto llevas de lo que el campo exige.
///
/// Mientras no alcanza el mínimo cuenta hacia él ("3/20 palabras"): es lo que
/// hace falta saber para poder enviar. Cumplido el mínimo pasa a mostrar el
/// espacio que queda ("120/200"). Pasarse del tope no se avisa porque no puede
/// ocurrir: `maxLength` deja de aceptar teclas.
///
/// Solo se ve mientras se escribe ese campo, y nunca en rojo — es una guía, no
/// un reproche; el rojo lo pone el error del campo al enviar.
///
/// Es la misma pieza que usa la app de aliados, para que un límite se cuente
/// igual en las dos.
class ContadorCampo extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode foco;
  final int maxLength;
  final int? minPalabras;
  final int? minCaracteres;

  const ContadorCampo({
    super.key,
    required this.controller,
    required this.foco,
    required this.maxLength,
    this.minPalabras,
    this.minCaracteres,
  });

  static int palabras(String texto) =>
      texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    if (!foco.hasFocus) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final texto = controller.text;
    final caracteres = texto.characters.length;

    String etiqueta;
    if (minPalabras != null) {
      final cuantas = palabras(texto);
      etiqueta = cuantas < minPalabras!
          ? '$cuantas/$minPalabras ${context.tr('words_label')}'
          : '$caracteres/$maxLength';
    } else if (minCaracteres != null && caracteres < minCaracteres!) {
      etiqueta = '$caracteres/$minCaracteres';
    } else {
      etiqueta = '$caracteres/$maxLength';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          etiqueta,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 11.5,
            color: themeProvider.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}


/// Versión para campos que viven dentro de un diálogo, donde llevar un
/// `FocusNode` por campo es más plomería que provecho.
///
/// `TextField.buildCounter` ya recibe el largo actual y si el campo tiene el
/// foco, así que el contador sale del propio campo: mismo texto y mismas reglas
/// que [ContadorCampo], sin estado que mantener. Cuando se pasa este builder,
/// Flutter ignora su `counterText`.
InputCounterWidgetBuilder contadorDeCampo({int? minCaracteres}) {
  return (
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (!isFocused || maxLength == null) return const SizedBox.shrink();

    final falta = minCaracteres != null && currentLength < minCaracteres;
    final etiqueta =
        falta ? '$currentLength/$minCaracteres' : '$currentLength/$maxLength';

    return Text(
      etiqueta,
      style: TextStyle(
        fontSize: 11.5,
        color: Provider.of<ThemeProvider>(context).secondaryTextColor,
      ),
    );
  };
}
