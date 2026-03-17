import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service.dart';
import '../providers/theme_provider.dart';

class AlliesByServiceScreen extends StatelessWidget {
  final Service service;

  const AlliesByServiceScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          service.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        backgroundColor: themeProvider.scaffoldBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        color: themeProvider.scaffoldBgColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                // Descripción del servicio
                Text(
                  'Descripción del servicio: Aquí se muestra la información detallada del servicio seleccionado, incluyendo características, precios y detalles importantes.',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.textColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Botón de acción
                ElevatedButton(
                  onPressed: () {
                    // Acción para contratar el servicio
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78BF32), // Verde
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 100,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Contratar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
