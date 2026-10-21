import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import 'package:restep/core/routes/app_routes.dart';
import 'package:restep/screens/profile/profile_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

const _email = 'patient@example.com';
final _now = DateTime(2026, 10, 21, 9);

/// Only [authTime] is read by deleteAccount.
class _FakeIdToken implements IdTokenResult {
  _FakeIdToken(this.authTime);

  @override
  final DateTime authTime;

  // Read by MockFirebaseAuth when it signs the user in.
  @override
  String get signInProvider => 'password';

  @override
  Map<String, dynamic>? get claims => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// mock_exceptions registers throws globally per (equal) user, so every test
// needs its own uid.
var _userCount = 0;

/// A signed-in user whose last sign-in was [age] ago.
MockUser _user(Duration age) => MockUser(
      uid: 'uid-${_userCount++}',
      email: _email,
      idTokenResult: _FakeIdToken(_now.subtract(age)),
    );

Future<FakeFirebaseFirestore> _seededFirestore() async {
  final firestore = FakeFirebaseFirestore();
  final patient = firestore.collection('patients').doc(_email);
  await patient.set({'email': _email, 'full_name': 'Test Patient'});
  await patient
      .collection('emergency_contacts')
      .doc('c1')
      .set({'name': 'Nora', 'phone': '+966 50 765 4321'});
  await patient.collection('fog_episodes').doc('e1').set({'duration': 4});
  await patient
      .collection('settings')
      .doc('preferences')
      .set({'reminder_preference': 'both'});
  return firestore;
}

/// How many of the seeded documents exist. Reads each by path: after a parent
/// document is deleted, fake_cloud_firestore's collection queries miss
/// sub-collection documents written back later (real Firestore does not).
Future<int> _documentCount(FakeFirebaseFirestore firestore) async {
  final patient = firestore.collection('patients').doc(_email);
  final docs = [
    patient,
    patient.collection('emergency_contacts').doc('c1'),
    patient.collection('fog_episodes').doc('e1'),
    patient.collection('settings').doc('preferences'),
  ];
  var count = 0;
  for (final doc in docs) {
    if ((await doc.get()).exists) count++;
  }
  return count;
}

FirebaseAuthService _service(MockUser user, FakeFirebaseFirestore firestore) {
  return FirebaseAuthService(
    auth: MockFirebaseAuth(signedIn: true, mockUser: user),
    firestore: firestore,
    clock: () => _now,
  );
}

void main() {
  group('FirebaseAuthService.deleteAccount', () {
    test('fresh session deletes the patient data and the account', () async {
      final firestore = await _seededFirestore();
      final user = _user(const Duration(minutes: 1));

      await _service(user, firestore).deleteAccount();

      expect(await _documentCount(firestore), 0);
    });

    test('old session asks for the password and deletes nothing', () async {
      final firestore = await _seededFirestore();
      final user = _user(const Duration(hours: 12));
      // If deletion were attempted anyway, it would fail like the real thing.
      whenCalling(Invocation.method(#delete, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      await expectLater(
        _service(user, firestore).deleteAccount(),
        throwsA(isA<ReauthenticationRequiredException>()),
      );

      expect(await _documentCount(firestore), 4);
    });

    test('old session with the correct password deletes everything',
        () async {
      final firestore = await _seededFirestore();
      final user = _user(const Duration(hours: 12));

      await _service(user, firestore).deleteAccount(password: 'Restep12!');

      expect(await _documentCount(firestore), 0);
    });

    test('wrong password keeps the account and data', () async {
      final firestore = await _seededFirestore();
      final user = _user(const Duration(hours: 12));
      whenCalling(Invocation.method(#reauthenticateWithCredential, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await expectLater(
        _service(user, firestore).deleteAccount(password: 'wrong'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('Incorrect password'))),
      );

      expect(await _documentCount(firestore), 4);
    });

    test('data is restored if Firebase still rejects the deletion', () async {
      // The session looked fresh on the device, but Firebase disagreed.
      final firestore = await _seededFirestore();
      final user = _user(const Duration(minutes: 1));
      whenCalling(Invocation.method(#delete, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      await expectLater(
        _service(user, firestore).deleteAccount(),
        throwsA(isA<ReauthenticationRequiredException>()),
      );

      expect(await _documentCount(firestore), 4);
      final contact = await firestore
          .collection('patients')
          .doc(_email)
          .collection('emergency_contacts')
          .doc('c1')
          .get();
      expect(contact.data(), {'name': 'Nora', 'phone': '+966 50 765 4321'});
    });

    test('data is restored on any other account deletion failure', () async {
      final firestore = await _seededFirestore();
      final user = _user(const Duration(minutes: 1));
      whenCalling(Invocation.method(#delete, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      await expectLater(
        _service(user, firestore).deleteAccount(),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('Network error'))),
      );

      expect(await _documentCount(firestore), 4);
    });
  });

  group('Delete Account on the Profile screen', () {
    Future<FakeFirebaseFirestore> pumpProfile(
      WidgetTester tester,
      MockUser user,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final firestore = await tester.runAsync(_seededFirestore);
      final app = AppState(
        authService: _service(user, firestore!),
        repository: MockDataRepository(),
        clock: () => _now,
      );
      await tester.pumpWidget(AppScope(
        state: app,
        child: MaterialApp(
          home: const Scaffold(body: ProfileScreen()),
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => Text('route:${settings.name}'),
          ),
        ),
      ));
      // Sign in from the existing Firebase session.
      final restore = app.restoreSession();
      await tester.pump(const Duration(seconds: 1));
      await restore;
      await tester.pumpAndSettle();
      return firestore;
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Delete Account'));
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account?'), findsOneWidget);
      await tester.tap(find.text('Delete Account').last);
    }

    testWidgets('old session asks for the password in place', (tester) async {
      final user = _user(const Duration(hours: 12));
      final firestore = await pumpProfile(tester, user);

      await confirmDelete(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your password'), findsOneWidget);
      expect(await tester.runAsync(() => _documentCount(firestore)), 4);

      // Cancelling keeps everything.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your password'), findsNothing);
      expect(await tester.runAsync(() => _documentCount(firestore)), 4);
    });

    testWidgets('old session deletes after the password is entered',
        (tester) async {
      final user = _user(const Duration(hours: 12));
      final firestore = await pumpProfile(tester, user);

      await confirmDelete(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'Restep12!',
      );
      await tester.tap(find.text('Delete Account').last);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('route:${Routes.login}'), findsOneWidget);
      expect(await tester.runAsync(() => _documentCount(firestore)), 0);
    });
  });
}
