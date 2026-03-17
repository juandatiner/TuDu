import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';

class DataProtectionScreen extends StatelessWidget {
  const DataProtectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

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
          loc.translate('data_protection'),
          style: TextStyle(
            color: themeProvider.textColor,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('data_protection_policy'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_collection_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_collection_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_usage_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_usage_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_sharing_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_sharing_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_security_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_security_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_rights_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_rights_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_cookies_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_cookies_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('data_contact_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78BF32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('data_contact_text'),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.translate('data_last_update'),
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.secondaryTextColor,
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
