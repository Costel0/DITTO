import 'package:flutter/material.dart';

import '../auth/session_controller.dart';
import '../screens/login_screen.dart';
import '../screens/welcome_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String welcome = '/welcome';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    SessionController sessionController,
  ) {
    switch (settings.name) {
      case welcome:
        // Temporary route guard. When real authentication is added, this is
        // the natural place to expand access-control/navigation logic.
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
