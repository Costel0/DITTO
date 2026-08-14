import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/application/session_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'navigation/app_routes.dart';

class DittoApp extends StatelessWidget {
  const DittoApp({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFC89A57);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFD2A35D),
      onPrimary: const Color(0xFF21180C),
      secondary: const Color(0xFF8C9B71),
      surface: const Color(0xFF211F1A),
      onSurface: const Color(0xFFE9DFCA),
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF11110E),
        dividerColor: const Color(0xFF4A4337),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: const Color(0xFFE0D6C4),
              displayColor: const Color(0xFFF1E7D1),
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171713),
          labelStyle: const TextStyle(color: Color(0xFFBEB29D)),
          hintStyle: const TextStyle(color: Color(0xFF756E62)),
          prefixIconColor: const Color(0xFFA99778),
          suffixIconColor: const Color(0xFFA99778),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xFF51493D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xFF51493D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(
              color: seedColor,
              width: 1.5,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC69855),
            foregroundColor: const Color(0xFF18130C),
            disabledBackgroundColor: const Color(0xFF5B5141),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFC8B58D),
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
