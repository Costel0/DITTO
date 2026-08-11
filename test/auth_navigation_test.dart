import 'package:ditto/auth/auth_service.dart';
import 'package:ditto/auth/session_controller.dart';
import 'package:ditto/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DittoApp buildApp() {
    return DittoApp(
      sessionController: SessionController(
        authService: PlaceholderAuthService(),
      ),
    );
  }

  testWidgets('opens registration from login', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Welcome to DITTO'), findsOneWidget);

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('registration validates password confirmation', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.enterText(find.byType(TextField).at(2), 'different');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}
