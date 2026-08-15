import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/ditto_app.dart';
import 'core/firebase/firebase_auth_service.dart';
import 'core/firebase/firebase_functions_bunker_setup_service.dart';
import 'core/firebase/firebase_functions_survivor_development_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/firebase/firestore_survivor_service.dart';
import 'core/firebase/firestore_user_profile_service.dart';
import 'features/auth/application/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Development currently uses App Check debug providers. Production builds
  // intentionally do not fall back to a debug provider; configure real
  // attestation providers before enabling a release build.
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
      providerWeb: WebDebugProvider(),
    );
  }

  final sessionController = SessionController(
    authService: FirebaseAuthService(),
    bunkerSetupService: FirebaseFunctionsBunkerSetupService(),
    survivorDevelopmentService:
        FirebaseFunctionsSurvivorDevelopmentService(),
    userProfileService: FirestoreUserProfileService(),
    survivorService: FirestoreSurvivorService(),
  );

  runApp(DittoApp(sessionController: sessionController));
}
