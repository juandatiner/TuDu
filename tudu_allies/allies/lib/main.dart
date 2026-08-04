import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
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
      // Localización para DatePicker en español
      locale: const Locale('es', 'CO'),
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const OnboardingScreen(),
    );
  }
}
