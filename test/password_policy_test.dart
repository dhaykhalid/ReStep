import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/core/utils/validators.dart';
import 'package:restep/screens/auth/sign_up_screen.dart';

void main() {
  group('Validators.newPassword', () {
    test('rejects weak passwords with a specific message', () {
      expect(Validators.newPassword(''), 'Password is required');
      expect(Validators.newPassword(null), 'Password is required');
      expect(Validators.newPassword('Ab1!'), contains('8 characters'));
      expect(Validators.newPassword('restep123!'), contains('uppercase'));
      expect(Validators.newPassword('RESTEP123!'), contains('lowercase'));
      expect(Validators.newPassword('Restep!!!'), contains('number'));
      expect(Validators.newPassword('Restep123'), contains('special'));
      expect(Validators.newPassword('123456'), isNotNull);
    });

    test('accepts passwords meeting all five requirements', () {
      for (final p in ['Restep12!', 'Abcdef1@', 'Pass#word9', r'Xy$12345',
          'Qwerty%7', 'a-B-c-1-2']) {
        expect(Validators.newPassword(p), isNull, reason: p);
        expect(PasswordPolicy.isValid(p), isTrue, reason: p);
      }
    });

    test('only Firebase-accepted symbols count as special characters', () {
      expect(PasswordPolicy.isValid('Restep123+'), isFalse);
      expect(PasswordPolicy.isValid('Restep123 '), isFalse);
      for (final c in PasswordPolicy.specialCharacters.split('')) {
        expect(PasswordPolicy.isValid('Restep12$c'), isTrue, reason: c);
      }
    });
  });

  test('sign-in validation does not apply the strength policy', () {
    expect(Validators.passwordPresent('abc'), isNull);
    expect(Validators.passwordPresent(''), 'Password is required');
  });

  test('confirm password must match', () {
    expect(Validators.confirmPassword('', 'Restep12!'), isNotNull);
    expect(Validators.confirmPassword('Restep12?', 'Restep12!'),
        'Passwords do not match');
    expect(Validators.confirmPassword('Restep12!', 'Restep12!'), isNull);
  });

  group('SignUpScreen', () {
    Future<void> pumpSignUp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
    }

    Finder field(String label) => find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.hintText == label);

    testWidgets('checklist updates live as the user types', (tester) async {
      await pumpSignUp(tester);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.enterText(field('Create a strong password'), 'abcdefgh');
      await tester.pump();
      // Length and lowercase are met.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

      await tester.enterText(field('Create a strong password'), 'Abcdefg1!');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
    });

    testWidgets('blocks submission for weak or mismatched passwords',
        (tester) async {
      await pumpSignUp(tester);
      await tester.enterText(field('Your full name'), 'Test User');
      await tester.enterText(field('name@example.com'), 'test@example.com');
      await tester.enterText(field('Create a strong password'), 'Restep123');
      await tester.enterText(field('Enter the password again'), 'Restep124');
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Include at least one special character, such as @ # \$ ! %'),
          findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
