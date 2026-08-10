import 'package:flutter_test/flutter_test.dart';
import 'package:ditto/auth/auth_service.dart';
import 'package:ditto/auth/session_controller.dart';
import 'package:ditto/main.dart';

void main() {
  DittoApp buildApp() {
    return DittoApp(
      sessionController: SessionController(
        authService: PlaceholderAuthService(),
      ),
    );
  }

  testWidgets('starts on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Welcome to DITTO'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('skip opens welcome screen with default user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Hello user'), findsOneWidget);
  });
}
