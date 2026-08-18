import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/ditto_app.dart';
import 'core/firebase/firebase_auth_service.dart';
import 'core/firebase/firebase_functions_bunker_setup_service.dart';
import 'core/firebase/firebase_functions_development_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/firebase/firestore_survivor_service.dart';
import 'core/firebase/firestore_user_profile_service.dart';
import 'features/auth/application/session_controller.dart';
import 'features/development/domain/app_check_debug_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Development uses fixed App Check debug tokens so local Web and Android
  // runs keep working across temporary browser profiles and emulator restarts.
  // Release builds intentionally do not use these providers.
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(
        debugToken: AppCheckDebugConfig.androidToken,
      ),
      providerApple: const AppleDebugProvider(),
      providerWeb: WebDebugProvider(
        debugToken: AppCheckDebugConfig.webToken,
      ),
    );
  }

  final sessionController = SessionController(
    authService: FirebaseAuthService(),
    bunkerSetupService: FirebaseFunctionsBunkerSetupService(),
    developmentService: FirebaseFunctionsDevelopmentService(),
    userProfileService: FirestoreUserProfileService(),
    survivorService: FirestoreSurvivorService(),
  );

  runApp(DittoApp(sessionController: sessionController));
}
