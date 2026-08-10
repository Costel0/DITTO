import 'package:flutter_test/flutter_test.dart';
import 'package:ditto/main.dart';

void main() {
  testWidgets('shows Hello World', (WidgetTester tester) async {
    await tester.pumpWidget(const DittoApp());

    expect(find.text('Hello World'), findsOneWidget);
  });
}
