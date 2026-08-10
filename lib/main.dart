// lib/main.dart
import 'package:flutter/material.dart';
import 'package:game_wiki/l10n/app_localizations.dart';
import 'menu_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ogame Wiki',
      debugShowCheckedModeBanner: false, // Quita la banda roja de "Debug"
      theme: ThemeData(
        brightness: Brightness.dark, // Modo oscuro global
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const MenuScreen(), // Aquí definimos que el Menú es la vista base
    );
  }
}
