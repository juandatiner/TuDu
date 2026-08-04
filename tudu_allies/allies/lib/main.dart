import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_store.dart';
import 'services/session_service.dart';

/// `runWithClient` hace que todas las llamadas de `package:http` de la app pasen
/// por el cliente que añade el `Authorization: Bearer`.
///
/// El arranque entero va dentro de la zona, `ensureInitialized()` incluido, para
/// no provocar el aviso de "Zone mismatch" de Flutter.
void main() {
  http.runWithClient(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // El token debe estar en memoria antes de la primera petición.
      await AuthStore.load();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SessionService()),
          ],
          child: const MyApp(),
        ),
      );
    },
    () => AuthenticatedClient(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuDu Aliados',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF78BF32),
          secondary: Color(0xFF78BF32),
        ),
        useMaterial3: true,
        // El rojo del error debe ganarle al verde de foco: sin estos bordes,
        // Flutter mezclaba ambos y el campo con error quedaba de un color
        // indefinido al enfocarlo.
        inputDecorationTheme: InputDecorationTheme(
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF44336), width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF44336), width: 2),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.red,
          contentTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // El idioma sale del dispositivo: antes estaba fijado a español y en un
      // teléfono en inglés igual salía todo en español.
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localeResolutionCallback: (deviceLocale, supported) {
        final idioma = deviceLocale?.languageCode;
        return idioma == 'en' ? const Locale('en') : const Locale('es');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const OnboardingScreen(),
    );
  }
}
