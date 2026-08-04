import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_in_search.dart';
import '../providers/theme_provider.dart';
import '../services/user_api.dart';
import '../l10n/app_localizations.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceInSearch service;
  final String userEmail;

  const ServiceDetailScreen(
      {super.key, required this.service, required this.userEmail});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isDeleting = false;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'EN ESPERA':
        return Colors.grey;
      case 'EN PROCESO':
        return Colors.orange;
      case 'TERMINADO':
        return Colors.green;
      case 'CANCELADO':
        return Colors.red;
      case 'RETRASADO':
        return Colors.deepOrange;
      case 'FINALIZADO':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Color _getThemeColor(String status) {
    // Para servicios en espera, usar gris como color temático
    if (status == 'EN ESPERA') {
      return Colors.grey;
    }
    return const Color(0xFF78BF32);
  }

  String _getStatusText(String status, BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'EN ESPERA':
        return loc?.translate('pending_assignment') ?? 'Pendiente por asignar';
      case 'EN PROCESO':
        return loc?.translate('in_process') ?? 'En proceso';
      case 'TERMINADO':
        return loc?.translate('finished') ?? 'Terminado';
      case 'CANCELADO':
        return loc?.translate('cancelled') ?? 'Cancelado';
      case 'RETRASADO':
        return loc?.translate('delayed') ?? 'Retrasado';
      case 'FINALIZADO':
        return loc?.translate('completed') ?? 'Finalizado';
      default:
        return status;
    }
  }

  String _formatBudget(String budget) {
    // El presupuesto ya viene formateado con comas desde el modelo
    // Solo necesitamos devolverlo tal cual
    return budget;
  }

  String _formatTimeUnit(int quantity, String unit, BuildContext context) {
    final loc = AppLocalizations.of(context);

    // Normalizar la unidad a minúsculas y singular para buscar
    final normalizedUnit =
        unit.toLowerCase().replaceAll('es', '').replaceAll('s', '');

    // Determinar si usar singular o plural basado en la cantidad
    final isSingular = quantity == 1;

    // Mapa de unidades normalizadas a sus claves de traducción
    final singularKeys = {
      'año': 'year_singular',
      'mes': 'month_singular',
      'semana': 'week_singular',
      'día': 'day_singular',
      'hora': 'hour_singular',
    };

    final pluralKeys = {
      'año': 'year_plural',
      'mes': 'month_plural',
      'semana': 'week_plural',
      'día': 'day_plural',
      'hora': 'hour_plural',
    };

    final keyMap = isSingular ? singularKeys : pluralKeys;
    final key = keyMap[normalizedUnit] ?? unit;
    return loc?.translate(key) ?? unit;
  }

  String _getFinishText(String status, BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'EN ESPERA':
        return loc?.translate('pending_assignment') ?? 'Pendiente por asignar';
      case 'EN PROCESO':
        return loc?.translate('in_development') ?? 'En desarrollo';
      case 'TERMINADO':
        return loc?.translate('finished') ?? 'Completado';
      case 'CANCELADO':
        return loc?.translate('cancelled') ?? 'Cancelado';
      case 'RETRASADO':
        return loc?.translate('in_delay') ?? 'En retraso';
      case 'FINALIZADO':
        return loc?.translate('completed') ?? 'Finalizado';
      default:
        return loc?.translate('pending_assignment') ?? 'Pendiente por asignar';
    }
  }

  String _getTranslatedStatus(String status, BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'EN ESPERA':
        return loc?.translate('waiting_status') ?? 'EN ESPERA';
      case 'EN PROCESO':
        return loc?.translate('in_process_status') ?? 'EN PROCESO';
      case 'TERMINADO':
        return loc?.translate('finished_status') ?? 'TERMINADO';
      case 'CANCELADO':
        return loc?.translate('cancelled_status') ?? 'CANCELADO';
      case 'RETRASADO':
        return loc?.translate('delayed_status') ?? 'RETRASADO';
      case 'FINALIZADO':
        return loc?.translate('completed_status') ?? 'FINALIZADO';
      default:
        return status;
    }
  }

  Future<void> _deleteService() async {
    final loc = AppLocalizations.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Mostrar diálogo de confirmación con estilo de la app
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeProvider.cardBgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                loc?.translate('stop_searching_ally') ??
                    'Dejar de buscar Aliado',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Mensaje
              Text(
                loc?.translate('stop_searching_confirmation') ??
                    '¿Estás seguro de que deseas dejar de buscar un Aliado para este servicio?',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        loc?.translate('cancel') ?? 'Cancelar',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        loc?.translate('delete') ?? 'Eliminar',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await ServicioService.eliminar(widget.service.id, widget.userEmail);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.translate('service_deleted_success') ??
                  'Servicio eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Regresar con resultado true
        }
    } catch (e) {
      print('Error deleting service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.translate('error_deleting_service') ??
                'Error al eliminar el servicio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeColor = _getThemeColor(widget.service.status);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc?.translate('service_details') ?? 'Detalles del Servicio',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: themeProvider.scaffoldBgColor,
        child: Column(
          children: [
            // Header fijo con gradiente (título y estado)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [themeColor, themeColor.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    Text(
                      widget.service.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Badge de estado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Text(
                        _getTranslatedStatus(widget.service.status, context),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(widget.service.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenido con scroll
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Tarjeta de Inicio y Finalización
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: themeProvider.cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Inicio
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: themeColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    loc?.translate('start') ?? 'Inicio',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getStatusText(
                                        widget.service.status, context),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // Divisor
                            Container(
                              height: 80,
                              width: 1,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[200],
                            ),

                            // Finalización
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.flag_rounded,
                                      color: themeColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    loc?.translate('finish') ?? 'Finalización',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFinishText(
                                        widget.service.status, context),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tarjeta de información
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: themeProvider.cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Aliado a cargo
                            _buildInfoSection(
                              icon: Icons.person_outline,
                              title: loc?.translate('ally_in_charge') ??
                                  'Aliado a cargo',
                              content: loc?.translate('pending_assignment') ??
                                  'Pendiente por asignar',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Descripción
                            _buildInfoSection(
                              icon: Icons.description_outlined,
                              title: loc?.translate('description') ??
                                  'Descripción',
                              content: widget.service.description,
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Tiempo estimado
                            _buildInfoSection(
                              icon: Icons.schedule_outlined,
                              title: loc?.translate('estimated_time') ??
                                  'Tiempo estimado',
                              content:
                                  '${widget.service.timeQuantity} ${_formatTimeUnit(widget.service.timeQuantity, widget.service.timeUnit, context)}',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Presupuesto
                            _buildInfoSection(
                              icon: Icons.attach_money,
                              title: loc?.translate('budget') ?? 'Presupuesto',
                              content:
                                  '\$${_formatBudget(widget.service.budget)}',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Información para el trabajador
                            _buildInfoSection(
                              icon: Icons.work_outline,
                              title: loc?.translate('worker_info') ??
                                  'Información para el trabajador',
                              content: widget.service.workerInfo.isNotEmpty
                                  ? widget.service.workerInfo
                                  : loc?.translate('no_additional_info') ??
                                      'Sin información adicional',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Fecha de publicación
                            _buildInfoSection(
                              icon: Icons.calendar_today_outlined,
                              title: loc?.translate('publication_date') ??
                                  'Fecha de publicación',
                              content:
                                  widget.service.createdAt.substring(0, 10),
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Botón "Dejar de buscar aliado" - Solo para servicios en búsqueda (EN ESPERA y sin asignar)
                      if (widget.service.status == 'EN ESPERA' &&
                          !widget.service.assigned)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _isDeleting ? null : _deleteService,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 3,
                            ),
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    loc?.translate('stop_searching_ally') ??
                                        'Dejar de buscar aliado',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
    required Color themeColor,
    required ThemeProvider themeProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: themeColor, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[200],
        thickness: 1,
      ),
    );
  }
}
