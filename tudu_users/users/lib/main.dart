import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'services/auth_store.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/user_avatar_provider.dart';
import 'services/session_service.dart';
import 'screens/onboarding_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // El token tiene que estar en memoria antes de la primera petición.
  await AuthStore.load();

  // Inicialización optimizada - cargar solo lo necesario para la splash
  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguage();

  // Reproducir sonido de forma asíncrona sin bloquear la UI
  _playSound();

  // `runWithClient` sustituye el cliente que usan las funciones de nivel
  // superior de `package:http`. Así toda llamada de la app (http.get, http.post,
  // …) viaja firmada con el token, sin tener que modificar cada pantalla.
  http.runWithClient(
    () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: languageProvider),
          ChangeNotifierProvider(create: (_) => SessionService()),
          ChangeNotifierProvider(create: (_) => UserAvatarProvider()),
        ],
        child: const MyApp(),
      ),
    ),
    () => AuthenticatedClient(),
  );
}

Future<void> _playSound() async {
  try {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/entrada.mp3'));
  } catch (e) {
    // Manejar errores de audio sin bloquear la app
    debugPrint('Error al reproducir sonido: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'TuDu',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Configuración de localización
      locale: languageProvider.locale,
      supportedLocales: LanguageProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Si el locale está soportado, usarlo
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // Si no, usar español por defecto
        return const Locale('es', 'CO');
      },

      home: const OnboardingScreen(),
    );
  }
}
