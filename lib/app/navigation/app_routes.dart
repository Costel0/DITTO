import 'package:flutter/material.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/username_setup_screen.dart';
import '../../features/home/presentation/screens/welcome_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String register = '/register';
  static const String usernameSetup = '/username';
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

      case usernameSetup:
        if (!sessionController.isAuthenticated) {
          return _loginRoute(sessionController);
        }
        if (!sessionController.needsProfileSetup) {
          return _welcomeRoute(sessionController);
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => UsernameSetupScreen(
            sessionController: sessionController,
          ),
        );

      case welcome:
        if (!sessionController.isAuthenticated) {
          return _loginRoute(sessionController);
        }
        if (sessionController.needsProfileSetup) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: usernameSetup),
            builder: (_) => UsernameSetupScreen(
              sessionController: sessionController,
            ),
          );
        }
        return _welcomeRoute(sessionController, settings: settings);

      case login:
      default:
        return _loginRoute(sessionController);
    }
  }

  static MaterialPageRoute<void> _loginRoute(
    SessionController sessionController,
  ) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: login),
      builder: (_) => LoginScreen(
        sessionController: sessionController,
      ),
    );
  }

  static MaterialPageRoute<void> _welcomeRoute(
    SessionController sessionController, {
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<void>(
      settings: settings ?? const RouteSettings(name: welcome),
      builder: (_) => WelcomeScreen(
        sessionController: sessionController,
      ),
    );
  }
}
