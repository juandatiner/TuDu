import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Apariencia',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Personaliza la apariencia de la aplicación según tus preferencias.',
                  style: TextStyle(
                      fontSize: 16, color: themeProvider.secondaryTextColor)),
              const SizedBox(height: 32),
              Text('Tema de la aplicación',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.textColor)),
              const SizedBox(height: 16),
              _buildThemeOption(
                  themeProvider,
                  Icons.light_mode,
                  'Modo Claro',
                  'Fondo claro con textos oscuros',
                  !isDark,
                  () => themeProvider.setDarkMode(false)),
              const SizedBox(height: 12),
              _buildThemeOption(
                  themeProvider,
                  Icons.dark_mode,
                  'Modo Oscuro',
                  'Fondo gris oscuro con textos claros',
                  isDark,
                  () => themeProvider.setDarkMode(true)),
              const SizedBox(height: 40),
              _buildInfoCard(themeProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeProvider themeProvider, IconData icon,
      String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? ThemeProvider.primaryColor
                  : themeProvider.borderColor,
              width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeProvider.primaryColor.withOpacity(0.15)
                  : themeProvider.borderColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isSelected
                    ? ThemeProvider.primaryColor
                    : themeProvider.secondaryTextColor,
                size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.textColor)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 14, color: themeProvider.secondaryTextColor)),
            ]),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isSelected ? ThemeProvider.primaryColor : Colors.transparent,
              border: Border.all(
                  color: isSelected
                      ? ThemeProvider.primaryColor
                      : themeProvider.borderColor,
                  width: 2),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoCard(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: ThemeProvider.primaryColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'El tema seleccionado se guardará automáticamente y se aplicará cada vez que abras la aplicación.',
            style: TextStyle(
                fontSize: 14, color: themeProvider.secondaryTextColor),
          ),
        ),
      ]),
    );
  }
}
