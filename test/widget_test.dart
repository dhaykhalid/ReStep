import 'package:flutter_test/flutter_test.dart';

import 'package:restep/app.dart';

void main() {
  testWidgets('ReStep opens on the login screen after the splash',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ReStepApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsWidgets);
  });
}
