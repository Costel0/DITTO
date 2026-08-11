import 'package:flutter/material.dart';

import '../auth/session_controller.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/welcome_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String register = '/register';
  static const String welcome = '/welcome';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    SessionController sessionController,
  ) {
    switch (settings.name) {
      case register:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RegisterScreen(
            sessionController: sessionController,
          ),
        );

      case welcome:
        if (!sessionController.isAuthenticated) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: login),
            builder: (_) => LoginScreen(
              sessionController: sessionController,
            ),
          );
        }

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WelcomeScreen(
            sessionController: sessionController,
          ),
        );

      case login:
      default:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: login),
          builder: (_) => LoginScreen(
            sessionController: sessionController,
          ),
        );
    }
  }
}
