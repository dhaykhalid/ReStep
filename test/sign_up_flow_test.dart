import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/core/routes/app_routes.dart';
import 'package:restep/screens/about/about_screen.dart';
import 'package:restep/screens/auth/sign_up_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

const _email = 'new.patient@example.com';
final _now = DateTime(2026, 10, 22, 9);

void main() {
  testWidgets('sign up goes straight to Home and saves the patient record',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: _email));
    final app = AppState(
      authService: FirebaseAuthService(
        auth: auth,
        firestore: firestore,
        clock: () => _now,
      ),
      repository: MockDataRepository(),
      clock: () => _now,
    );
    final visited = <String?>[];
    await tester.pumpWidget(AppScope(
      state: app,
      child: MaterialApp(
        home: const SignUpScreen(),
        onGenerateRoute: (settings) {
          visited.add(settings.name);
          return MaterialPageRoute(
            builder: (_) => Text('route:${settings.name}'),
          );
        },
      ),
    ));

    Finder field(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint);
    await tester.enterText(field('Your full name'), 'Dhai Khalid');
    await tester.enterText(field('name@example.com'), _email);
    await tester.enterText(field('Create a strong password'), 'Restep12!');
    await tester.enterText(field('Enter the password again'), 'Restep12!');
    await tester.tap(find.text('Create Account'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('route:${Routes.home}'), findsOneWidget);
    expect(visited, [Routes.home], reason: 'no profile setup step');

    final doc = await tester.runAsync(
        () => firestore.collection('patients').doc(_email).get());
    expect(doc!.data(), {
      'email': _email,
      'full_name': 'Dhai Khalid',
      'birth_date': null,
      'waiting_time': null,
    });
    expect(app.patient?.fullName, 'Dhai Khalid');
    expect(app.patient?.email, _email);
    expect(app.patient?.dateOfBirth, isNull);

    // Signing out and back in loads the same record.
    await tester.runAsync(app.signOut);
    expect(app.isSignedIn, isFalse);
    await tester.runAsync(() => app.signIn(_email, 'Restep12!'));
    expect(app.patient?.fullName, 'Dhai Khalid');
    expect(app.escalation.waitSeconds, 30);
  });

  testWidgets('About shows the new content and fits a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    const expected = [
      'What ReStep does',
      'Monitors your movement using a Shimmer3 IMU sensor.',
      'Detects Freezing of Gait (FoG) episodes in real time.',
      'Provides vibration or auditory cues through your smartwatch to help '
          'you resume movement.',
      'Records FoG episodes and allows you to review your history and '
          'generate reports.',
      'Helps you organize daily activities through personalized reminders.',
      'Sends an emergency alert with your location to your emergency '
          'contact when predefined conditions are met.',
      'What ReStep does not do',
      'Does not predict Freezing of Gait (FoG) episodes before they occur.',
      'Does not provide cueing methods other than vibration and auditory '
          'cues.',
      'Does not provide medical diagnoses, clinical interpretations, or '
          'treatment recommendations.',
      'Does not verify medication dosages or check for drug interactions.',
      'Your data',
      'Your personal information and all data stored in ReStep are '
          'protected and accessible only through your account.',
      'Continuous raw sensor data is not permanently stored by default.',
      'Your reports are shared with healthcare professionals only when you '
          'choose to export and share them.',
      'Language',
      'ReStep is currently available in English.',
    ];
    for (final text in expected) {
      await tester.scrollUntilVisible(find.text(text), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.textContaining('It does not'), findsNothing);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });
}
