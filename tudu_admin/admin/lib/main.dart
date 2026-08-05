import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'services/auth_store.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

/// Todas las llamadas del panel viajan firmadas con el token de admin.
///
/// El arranque entero va dentro de la zona, `ensureInitialized()` incluido, para
/// no provocar el aviso de "Zone mismatch" de Flutter.
void main() {
  http.runWithClient(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // El token debe estar en memoria antes de la primera petición.
      await AuthStore.load();

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      runApp(const MyApp());
    },
    () => AuthenticatedClient(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuDu Admin',
      theme: ThemeData(
        primaryColor: Config.primaryColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Config.secondaryColor,
        ),
        scaffoldBackgroundColor: Config.backgroundColor,
        // Doble fondo — barra blanca sobre cuerpo gris — igual que
        // `user_services_screen.dart` en users (appBar = cardBg blanco,
        // scaffold = scaffoldBg gris). Antes era una barra verde sólida con
        // texto blanco, la única pantalla del ecosistema con ese estilo.
        appBarTheme: const AppBarTheme(
          backgroundColor: Config.whiteColor,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Config.primaryColor,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Config.primaryColor,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          // Mismo criterio que users/allies: verde al enfocar, rojo si hay
          // error (y le gana al verde aunque el campo tenga el foco puesto).
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Config.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Config.redColor, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Config.redColor, width: 2),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const OnboardingScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
