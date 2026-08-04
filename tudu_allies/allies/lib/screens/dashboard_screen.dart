import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/ally_api.dart';
import '../models/service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Service> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final servicesJson = await ServicioApi.catalogo();
      setState(() {
        _services = servicesJson.map((json) => Service.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Allies'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(context.tr('available_services'), style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return ListTile(
                    title: Text(service.name),
                    trailing: ElevatedButton(
                      onPressed: () {
                        // Acción para aceptar servicio
                      },
                      child: Text(context.tr('accept')),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}