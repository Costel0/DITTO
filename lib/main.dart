import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/ditto_app.dart';
import 'core/firebase/firebase_auth_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/firebase/firestore_user_profile_service.dart';
import 'features/auth/application/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final sessionController = SessionController(
    authService: FirebaseAuthService(),
    userProfileService: FirestoreUserProfileService(),
  );

  runApp(DittoApp(sessionController: sessionController));
}
