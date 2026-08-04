import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Piezas comunes para validar formularios.
///
/// Antes cada pantalla avisaba distinto: un SnackBar nombrando el primer campo
/// que faltaba ("Por favor ingresa nombre y apellido"), sin marcar nada en la
/// pantalla, así que había que adivinar dónde estaba el hueco y se descubrían
/// los errores de a uno.
///
/// El criterio ahora es el mismo de "Mis direcciones": se validan **todos** los
/// campos de una, cada campo con problema se marca en rojo con su motivo
/// debajo, y el aviso general dice solo que hay campos por completar.
class Validacion {
  static const Color colorError = Color(0xFFF44336);

  /// Aviso general que va pegado al botón de enviar.
  static Widget aviso(BuildContext context, String? mensaje) {
    if (mensaje == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorError.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorError.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: colorError, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: colorError, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Texto del aviso general: no nombra campos, para eso está la marca roja.
  static String textoCamposFaltantes(BuildContext context) =>
      context.tr('complete_all_fields');

  /// Motivo que se pinta debajo de un campo vacío.
  static String requerido(BuildContext context) => context.tr('field_required');

  static const Color colorOk = Color(0xFF78BF32);

  /// Bordes de un campo según su estado.
  ///
  /// Regla: **rojo** si falta o está mal (gana siempre, incluso con el foco
  /// puesto), **verde** solo mientras el campo tiene el foco, **gris** cuando
  /// está bien y sin foco. Nunca dos colores a la vez: antes el verde de foco
  /// se dibujaba encima del rojo y el campo quedaba con dos bordes.
  static InputDecoration decorar(
    InputDecoration base, {
    String? error,
    double radio = 12,
  }) {
    if (error == null) {
      // Sin error el tema ya pone gris en reposo y verde al enfocar.
      return base.copyWith(errorText: null);
    }

    final rojo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radio),
      borderSide: const BorderSide(color: colorError, width: 2),
    );

    return base.copyWith(
      errorText: error,
      border: rojo,
      enabledBorder: rojo,
      focusedBorder: rojo,
      errorBorder: rojo,
      focusedErrorBorder: rojo,
    );
  }


  /// Campo dibujado dentro de un Container que ya pinta su propio borde.
  ///
  /// Si el campo está mal, el rojo lo pinta el Container y el campo no dibuja
  /// nada — así no aparecen dos bordes encima (el verde de foco sobre el rojo).
  /// Si está bien, el campo pone el verde solo mientras tiene el foco.
  static InputDecoration campoEnContenedor(
    InputDecoration base, {
    String? error,
    double radio = 12,
  }) {
    OutlineInputBorder linea(Color color, double grosor) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: color, width: grosor),
        );

    final invisible = linea(Colors.transparent, 0);

    if (error != null) {
      return base.copyWith(
        border: invisible,
        enabledBorder: invisible,
        focusedBorder: invisible,
        errorBorder: invisible,
        focusedErrorBorder: invisible,
      );
    }

    return base.copyWith(
      border: invisible,
      enabledBorder: invisible,
      focusedBorder: linea(colorOk, 2),
    );
  }

  /// Mensaje corto bajo un campo dibujado a mano.
  static Widget mensajeCampo(String? error) {
    if (error == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        error,
        style: const TextStyle(fontSize: 12, color: colorError),
      ),
    );
  }
}
