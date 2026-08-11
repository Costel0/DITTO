import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/firebase_auth_service.dart';
import 'auth/session_controller.dart';
import 'firebase_options.dart';
import 'navigation/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final sessionController = SessionController(
    authService: FirebaseAuthService(),
  );

  runApp(DittoApp(sessionController: sessionController));
}

class DittoApp extends StatelessWidget {
  const DittoApp({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF5B5FEF);

    return MaterialApp(
      title: 'DITTO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE0E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE0E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: seedColor,
              width: 1.6,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings,
        sessionController,
      ),
    );
  }
}
