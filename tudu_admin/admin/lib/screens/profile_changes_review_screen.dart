import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/admin_api.dart';

/// Revisión de los cambios que un aliado hace a su perfil comercial.
///
/// El texto del perfil es lo que el usuario lee antes de contratar, así que una
/// edición no se publica sola: entra acá con el texto de hoy al lado del
/// propuesto y solo cambia cuando un admin lo aprueba. Mismo patrón que la
/// revisión de KYC y la de servicios propuestos.
class CambiosPerfilReviewScreen extends StatefulWidget {
  const CambiosPerfilReviewScreen({super.key});

  @override
  State<CambiosPerfilReviewScreen> createState() =>
      _CambiosPerfilReviewScreenState();
}

class _CambiosPerfilReviewScreenState extends State<CambiosPerfilReviewScreen> {
  List<Map<String, dynamic>> _solicitudes = [];
  bool _cargando = true;
  String _estado = 'pending';
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
      final datos = await CambiosPerfilAdminApi.listar(estado: _estado);
      if (!mounted) return;
      setState(() {
        _solicitudes = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _selectorEstado(),
        Expanded(child: _contenido()),
      ],
    );
  }

  Widget _selectorEstado() {
    const opciones = {
      'pending': 'Pendientes',
      'approved': 'Aprobados',
      'rejected': 'Rechazados',
      'todos': 'Todos',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: opciones.entries.map((o) {
          final activo = _estado == o.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.value),
              selected: activo,
              onSelected: (_) {
                setState(() => _estado = o.key);
                _cargar();
              },
              selectedColor: Config.primaryColor,
              labelStyle: TextStyle(
                color: activo ? Colors.white : Colors.black87,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: Config.primaryColor));
    }

    if (_error != null) {
      return _mensajeCentral(Icons.cloud_off, _error!,
          accion: 'Reintentar', onAccion: _cargar);
    }

    if (_solicitudes.isEmpty) {
      return _mensajeCentral(
        Icons.fact_check_outlined,
        _estado == 'pending'
            ? 'No hay cambios de perfil pendientes'
            : 'No hay cambios en este estado',
        accion: 'Actualizar',
        onAccion: _cargar,
      );
    }

    return RefreshIndicator(
      color: Config.primaryColor,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _solicitudes.length,
        itemBuilder: (_, i) => _tarjeta(_solicitudes[i]),
      ),
    );
  }

  Widget _mensajeCentral(IconData icono, String texto,
      {String? accion, VoidCallback? onAccion}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 72, color: Colors.black26),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          if (accion != null) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: onAccion, child: Text(accion)),
          ],
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> s) {
    final estado = s['status'] ?? 'pending';
    final pendiente = estado == 'pending';
    final actual = Map<String, dynamic>.from(s['actual'] ?? const {});

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: pendiente ? Colors.red.withOpacity(0.6) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pendiente)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (s['ally_nombre'] as String?)?.trim().isNotEmpty == true
                            ? s['ally_nombre']
                            : s['ally_email'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s['ally_email'] ?? '',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _pildoraEstado(estado),
              ],
            ),
            const SizedBox(height: 14),

            // Lo publicado contra lo propuesto: solo se marcan los campos que
            // de verdad cambiaron, para no leer tres bloques buscando cuál es.
            _comparacion('Nombre comercial', actual['nombre_comercial'],
                s['nombre_comercial']),
            _comparacion('Frase corta', actual['frase_presentacion'],
                s['frase_presentacion']),
            _comparacion('Resumen profesional', actual['resumen'], s['resumen']),

            if (estado == 'rejected' &&
                (s['rejection_reason'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                'Motivo: ${s['rejection_reason']}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF8C2018), height: 1.4),
              ),
            ],

            if (pendiente) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rechazar(s),
                      icon: const Icon(Icons.close, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(0, 44),
                      ),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resolver(s, 'approved'),
                      icon: const Icon(Icons.check, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Config.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                      ),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pildoraEstado(String estado) {
    const colores = {
      'pending': Colors.orange,
      'approved': Config.primaryColor,
      'rejected': Colors.red,
    };
    const textos = {
      'pending': 'Pendiente',
      'approved': 'Aprobado',
      'rejected': 'Rechazado',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colores[estado] ?? Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        textos[estado] ?? estado,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Un campo: el texto publicado tachado arriba y el propuesto debajo. Si no
  /// cambió, se muestra en gris y sin resaltar.
  Widget _comparacion(String etiqueta, String? antes, String? despues) {
    final cambio = (antes ?? '') != (despues ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cambio ? Colors.black87 : Colors.grey[600],
                ),
              ),
              if (cambio) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('cambia',
                      style: TextStyle(fontSize: 10, color: Color(0xFF6B4A00))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (cambio && (antes ?? '').isNotEmpty)
            Text(
              antes!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                decoration: TextDecoration.lineThrough,
                height: 1.4,
              ),
            ),
          Text(
            (despues ?? '').isEmpty ? '—' : despues!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cambio ? Colors.black : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rechazar(Map<String, dynamic> s) async {
    final controller = TextEditingController();

    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar el cambio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El aliado ve este motivo en su pantalla de datos. Sé concreto: '
              'es lo único que tiene para corregir.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: el resumen incluye un número de teléfono',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (motivo == null || motivo.isEmpty) return;
    await _resolver(s, 'rejected', motivo: motivo);
  }

  Future<void> _resolver(Map<String, dynamic> s, String estado,
      {String? motivo}) async {
    try {
      await CambiosPerfilAdminApi.revisar(s['id'] as int, estado,
          motivo: motivo);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(estado == 'approved'
            ? 'Cambio aprobado y publicado'
            : 'Cambio rechazado'),
        backgroundColor:
            estado == 'approved' ? Config.primaryColor : Colors.red,
      ));

      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar con el servidor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
