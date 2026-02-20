import 'package:flutter/material.dart';

class DataProtectionScreen extends StatelessWidget {
  const DataProtectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Protección de Datos',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Contenido de protección de datos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Política de Protección de Datos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '1. Recopilación de información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Recopilamos información que usted nos proporciona directamente, como su nombre, correo electrónico, número de teléfono y otra información necesaria para brindarle nuestros servicios.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '2. Uso de la información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Utilizamos su información para proporcionar, mantener y mejorar nuestros servicios, procesar transacciones, enviar comunicaciones relacionadas con el servicio y proteger contra fraudes.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '3. Compartir información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No vendemos ni alquilamos su información personal a terceros. Solo compartimos su información con proveedores de servicios que nos ayudan a operar nuestra aplicación y cumplir con la ley.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '4. Seguridad de datos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Implementamos medidas de seguridad técnicas y organizativas para proteger su información personal contra acceso no autorizado, alteración, divulgación o destrucción.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '5. Sus derechos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Usted tiene derecho a acceder, corregir, eliminar y portar su información personal. También tiene derecho a oponerse al procesamiento de sus datos en ciertas circunstancias.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '6. Cookies y tecnologías similares',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Utilizamos cookies y tecnologías similares para mejorar su experiencia, analizar el uso de nuestra aplicación y personalizar el contenido que se le muestra.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '7. Contacto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Si tiene preguntas sobre esta política de protección de datos, puede contactarnos a través de la sección de soporte de la aplicación.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Fecha de última actualización: Febrero 2026',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
