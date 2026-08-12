import 'package:flutter/material.dart';

/// Piezas comunes para validar formularios (mismo criterio que la app de
/// usuarios).
///
/// Antes cada pantalla avisaba con un SnackBar nombrando el primer campo que
/// faltaba y sin marcar nada, así que los errores se descubrían de a uno. Ahora
/// se validan todos juntos: cada campo con problema queda en rojo con su motivo
/// debajo y el aviso general solo dice que hay campos por completar.
class Validacion {
  static const Color colorError = Color(0xFFF44336);

  static const String textoCamposFaltantes =
      'Completa todos los campos marcados en rojo';
  static const String requerido = 'Campo obligatorio';

  /// Palabras de un texto, para los mínimos que se cuentan en palabras y no en
  /// caracteres (frase de presentación, experiencia, descripción del servicio).
  /// Diez caracteres los cumple "puertas ok"; cinco palabras obligan a decir algo.
  static int palabras(String texto) =>
      texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;

  /// Aviso general, pensado para ir pegado al botón de enviar.
  static Widget aviso(String? mensaje) {
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

  /// Mensaje corto bajo un campo dibujado a mano (selectores, cajas de imagen).
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

  /// Borde rojo para contenedores que no usan InputDecoration.
  static BoxBorder borde(bool hayError, {Color? normal}) => Border.all(
        color: hayError ? colorError : (normal ?? Colors.transparent),
        width: 2,
      );
}
