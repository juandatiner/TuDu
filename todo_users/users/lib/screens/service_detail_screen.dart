import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_in_search.dart';
import '../providers/theme_provider.dart';

class ServiceDetailScreen extends StatelessWidget {
  final ServiceInSearch service;

  const ServiceDetailScreen({super.key, required this.service});

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

  String _getStatusText(String status) {
    switch (status) {
      case 'EN ESPERA':
        return 'Pendiente por asignar';
      case 'EN PROCESO':
        return 'En proceso';
      case 'TERMINADO':
        return 'Terminado';
      case 'CANCELADO':
        return 'Cancelado';
      case 'RETRASADO':
        return 'Retrasado';
      case 'FINALIZADO':
        return 'Finalizado';
      default:
        return status;
    }
  }

  String _formatBudget(String budget) {
    // El presupuesto ya viene formateado con comas desde el modelo
    // Solo necesitamos devolverlo tal cual
    return budget;
  }

  String _formatTimeUnit(int quantity, String unit) {
    // Mapa de unidades en plural a singular
    final singularUnits = {
      'años': 'año',
      'meses': 'mes',
      'semanas': 'semana',
      'días': 'día',
      'horas': 'hora',
      'año': 'año',
      'mes': 'mes',
      'semana': 'semana',
      'día': 'día',
      'hora': 'hora',
    };

    final singularUnit = singularUnits[unit.toLowerCase()] ?? unit;
    return quantity == 1
        ? singularUnit
        : '${singularUnit}${unit.toLowerCase() == 'mes' ? 'es' : 's'}';
  }

  String _getFinishText(String status) {
    switch (status) {
      case 'EN ESPERA':
        return 'Pendiente por asignar';
      case 'EN PROCESO':
        return 'En desarrollo';
      case 'TERMINADO':
        return 'Completado';
      case 'CANCELADO':
        return 'Cancelado';
      case 'RETRASADO':
        return 'En retraso';
      case 'FINALIZADO':
        return 'Finalizado';
      default:
        return 'Pendiente por asignar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeColor = _getThemeColor(service.status);

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
          'Detalles del Servicio',
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
                      service.title,
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
                        service.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(service.status),
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
                                    'Inicio',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getStatusText(service.status),
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
                                    'Finalización',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFinishText(service.status),
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
                              title: 'Aliado a cargo',
                              content: 'Pendiente por asignar',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Descripción
                            _buildInfoSection(
                              icon: Icons.description_outlined,
                              title: 'Descripción',
                              content: service.description,
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Tiempo estimado
                            _buildInfoSection(
                              icon: Icons.schedule_outlined,
                              title: 'Tiempo estimado',
                              content:
                                  '${service.timeQuantity} ${_formatTimeUnit(service.timeQuantity, service.timeUnit)}',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Presupuesto
                            _buildInfoSection(
                              icon: Icons.attach_money,
                              title: 'Presupuesto',
                              content: '\$${_formatBudget(service.budget)}',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Información para el trabajador
                            _buildInfoSection(
                              icon: Icons.work_outline,
                              title: 'Información para el trabajador',
                              content: service.workerInfo.isNotEmpty
                                  ? service.workerInfo
                                  : 'Sin información adicional',
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),

                            _buildDivider(themeProvider),

                            // Fecha de publicación
                            _buildInfoSection(
                              icon: Icons.calendar_today_outlined,
                              title: 'Fecha de publicación',
                              content: service.createdAt.substring(0, 10),
                              themeColor: themeColor,
                              themeProvider: themeProvider,
                            ),
                          ],
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
