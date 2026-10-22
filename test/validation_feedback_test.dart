import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/screens/auth/sign_up_screen.dart';

void main() {
  Future<void> pumpSignUp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
  }

  Finder field(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint);

  String? errorOf(WidgetTester tester, String hint) =>
      tester.widget<TextField>(field(hint)).decoration?.errorText;

  const emailHint = 'name@example.com';
  const nameHint = 'Your full name';
  const invalidEmail = 'Enter a valid email address, such as name@example.com';

  testWidgets('untouched fields show no errors', (tester) async {
    await pumpSignUp(tester);
    expect(errorOf(tester, nameHint), isNull);
    expect(errorOf(tester, emailHint), isNull);

    // Focusing and leaving a field without typing is not an interaction.
    await tester.showKeyboard(field(emailHint));
    await tester.showKeyboard(field(nameHint));
    await tester.pump();
    expect(errorOf(tester, emailHint), isNull);
  });

  testWidgets('email: quiet while typing, checked on leaving, then live',
      (tester) async {
    await pumpSignUp(tester);

    await tester.enterText(field(emailHint), 'dhai');
    await tester.pump();
    expect(errorOf(tester, emailHint), isNull,
        reason: 'no error while typing for the first time');

    await tester.showKeyboard(field(nameHint)); // move to another field
    await tester.pump();
    expect(errorOf(tester, emailHint), invalidEmail);

    await tester.enterText(field(emailHint), 'dhai@example.com');
    await tester.pump();
    expect(errorOf(tester, emailHint), isNull,
        reason: 'error clears as soon as the email is valid');

    await tester.enterText(field(emailHint), 'dhai@example');
    await tester.pump();
    expect(errorOf(tester, emailHint), invalidEmail,
        reason: 'error returns when the email becomes invalid again');
  });

  testWidgets('submit shows every error, which then clear live',
      (tester) async {
    await pumpSignUp(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(errorOf(tester, nameHint), 'Full name is required');
    expect(errorOf(tester, emailHint), 'Email is required');
    expect(errorOf(tester, 'Create a strong password'), 'Password is required');
    expect(errorOf(tester, 'Enter the password again'),
        'Please confirm your password');

    await tester.enterText(field(nameHint), 'Dhai');
    await tester.pump();
    expect(errorOf(tester, nameHint), isNull);
    // Other fields keep their errors until they are fixed.
    expect(errorOf(tester, emailHint), 'Email is required');

    await tester.enterText(field(nameHint), '');
    await tester.pump();
    expect(errorOf(tester, nameHint), 'Full name is required');
  });

  testWidgets('confirm password re-checks when the password changes',
      (tester) async {
    await pumpSignUp(tester);
    await tester.enterText(field('Create a strong password'), 'Restep12!');
    await tester.enterText(field('Enter the password again'), 'Restep12?');
    await tester.showKeyboard(field(nameHint));
    await tester.pump();
    expect(errorOf(tester, 'Enter the password again'),
        'Passwords do not match');

    await tester.enterText(field('Create a strong password'), 'Restep12?');
    await tester.pump();
    expect(errorOf(tester, 'Enter the password again'), isNull);
  });
}
