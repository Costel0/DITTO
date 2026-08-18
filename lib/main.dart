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

  // Development uses App Check debug providers. Web's fixed debug token is set
  // in web/index.html before Flutter/Firebase loads, as required by the Web SDK.
  // Android receives its fixed token directly. Release builds intentionally do
  // not use debug providers.
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(
        debugToken: AppCheckDebugConfig.androidToken,
      ),
      providerApple: const AppleDebugProvider(),
      providerWeb: WebDebugProvider(),
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
