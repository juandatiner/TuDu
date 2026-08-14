import 'package:flutter/material.dart';

import 'validacion_formulario.dart';

/// Paleta del formulario, copiada del tema claro de la app de usuarios
/// (`ThemeProvider`) para que las dos pantallas se vean iguales.
class CampoColores {
  static const Color marca = Color(0xFF78BF32);
  static const Color fondo = Color(0xFFF4F2F2);
  static const Color textoSecundario = Color(0xFF666666);

  /// Gris del dato bloqueado. `grey[100]` (#F5F5F5) es casi el color del fondo
  /// y el campo parecía blanco.
  static const Color bloqueado = Color(0xFFE6E4E4);

  static final Color sombra = Colors.grey.withOpacity(0.2);
}

/// Caja de un dato: ícono a la izquierda, etiqueta arriba y valor debajo, las
/// dos dentro del rectángulo.
///
/// La etiqueta es texto propio y no la flotante de `InputDecoration`: esa, con
/// `InputBorder.none`, se dibuja por encima del borde y parte la tarjeta por
/// arriba. Así además todas las cajas miden lo mismo, sean editables, de solo
/// lectura o selectores.
class CampoCaja extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Widget hijo;
  final bool bloqueado;
  final bool hayError;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Solo para campos de varias líneas (el resumen): ahí centrar el ícono lo
  /// deja flotando a media caja. En todos los demás va centrado, como en users.
  final bool iconoArriba;

  const CampoCaja({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.hijo,
    this.bloqueado = false,
    this.hayError = false,
    this.onTap,
    this.trailing,
    this.iconoArriba = false,
  });

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bloqueado ? CampoColores.bloqueado : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hayError
            ? Border.all(color: Validacion.colorError, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: CampoColores.sombra,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            iconoArriba ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: iconoArriba ? 2 : 0),
            child: Icon(icono,
                size: 21,
                color: bloqueado
                    ? CampoColores.textoSecundario
                    : CampoColores.marca),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: const TextStyle(
                        fontSize: 12, color: CampoColores.textoSecundario)),
                const SizedBox(height: 1),
                hijo,
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) return caja;
    return GestureDetector(onTap: onTap, child: caja);
  }
}

/// Dato que se ve pero no se toca (los que fija la verificación de identidad).
class CampoBloqueado extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const CampoBloqueado({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return CampoCaja(
      icono: icono,
      etiqueta: etiqueta,
      bloqueado: true,
      hijo: Text(
        valor.isEmpty ? '—' : valor,
        style: const TextStyle(
            fontSize: 16, color: CampoColores.textoSecundario),
      ),
    );
  }
}

/// Encabezado de un bloque de campos, con su aclaración opcional.
class TituloBloque extends StatelessWidget {
  final String texto;
  final String? ayuda;

  const TituloBloque(this.texto, {super.key, this.ayuda});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
          if (ayuda != null) ...[
            const SizedBox(height: 4),
            Text(ayuda!,
                style: const TextStyle(
                    fontSize: 12,
                    color: CampoColores.textoSecundario,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Aclaración pequeña bajo un bloque de campos.
class NotaBloque extends StatelessWidget {
  final String texto;

  const NotaBloque(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          texto,
          style: const TextStyle(
              fontSize: 12, color: CampoColores.textoSecundario, height: 1.4),
        ),
      ),
    );
  }
}
