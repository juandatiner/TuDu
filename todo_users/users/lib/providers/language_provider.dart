import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para manejar el idioma de la aplicación
/// Soporta español (es) e inglés (en)
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('es', 'CO');

  Locale get locale => _locale;

  bool get isSpanish => _locale.languageCode == 'es';
  bool get isEnglish => _locale.languageCode == 'en';

  /// Inicializa el idioma desde SharedPreferences
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);

    if (languageCode != null) {
      _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');
      notifyListeners();
    }
  }

  /// Cambia el idioma de la aplicación
  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);

    _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');
    notifyListeners();
  }

  /// Alterna entre español e inglés
  Future<void> toggleLanguage() async {
    if (isSpanish) {
      await setLanguage('en');
    } else {
      await setLanguage('es');
    }
  }

  /// Lista de idiomas soportados
  static const List<Locale> supportedLocales = [
    Locale('es', 'CO'),
    Locale('en', 'US'),
  ];

  /// Nombres de los idiomas para mostrar en la UI
  static const Map<String, String> languageNames = {
    'es': 'Español',
    'en': 'English',
  };

  /// Nombres nativos de los idiomas
  static const Map<String, String> nativeLanguageNames = {
    'es': 'Español (Colombia)',
    'en': 'English (US)',
  };
}
