import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/models/patient.dart';
import 'package:restep/models/routine.dart';
import 'package:restep/screens/routine/routine_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

const _email = 'patient@example.com';
// Saturday 24 October 2026, 9:00 AM.
final _now = DateTime(2026, 10, 24, 9);

/// Lets a test make the next toggle or delete fail.
class _FlakyRepository extends MockDataRepository {
  bool fail = false;

  @override
  Future<void> setReminderEnabled(String id, bool enabled) async {
    if (fail) throw Exception('offline');
  }

  @override
  Future<void> deleteReminder(String id) async {
    if (fail) throw Exception('offline');
  }
}

Reminder _reminder(
  String id,
  String title, {
  ReminderFrequency frequency = ReminderFrequency.once,
  DateTime? date,
  List<String> days = const [],
  TimeOfDay time = const TimeOfDay(hour: 10, minute: 0),
  bool enabled = true,
}) =>
    Reminder(
      id: id,
      title: title,
      frequency: frequency,
      date: date,
      repeatDays: days,
      time: time,
      location: '',
      isEnabled: enabled,
    );

Future<(AppState, _FlakyRepository)> _state(List<Reminder> reminders) async {
  final repository = _FlakyRepository();
  final app = AppState(
    authService: FirebaseAuthService(
      auth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    ),
    repository: repository,
    clock: () => _now,
  );
  for (final r in reminders) {
    await app.saveReminder(r);
  }
  return (app, repository);
}

Future<void> _pump(WidgetTester tester, AppState app,
    {double width = 1080}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope(
    state: app,
    child: const MaterialApp(home: Scaffold(body: RoutineScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final sample = [
    _reminder('appt', 'Doctor appointment',
        date: DateTime(2026, 10, 28),
        time: const TimeOfDay(hour: 14, minute: 30),
        enabled: false),
    _reminder('walk', 'Walking exercise',
        frequency: ReminderFrequency.weekly, days: ['Mon', 'Wed', 'Fri']),
    _reminder('meds', 'Take medication',
        frequency: ReminderFrequency.daily,
        time: const TimeOfDay(hour: 9, minute: 30)),
  ];

  group('Reminders screen', () {
    testWidgets('one "Your Reminders" list, no Next/Later or Dismiss',
        (tester) async {
      final (app, _) = await _state(sample);
      await _pump(tester, app);

      expect(find.text('Your Reminders'), findsOneWidget);
      expect(find.text('Next reminder'), findsNothing);
      expect(find.textContaining('Later'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
      expect(find.byType(Switch), findsNWidgets(3));

      expect(find.text('Every day · 9:30 AM'), findsOneWidget);
      expect(find.text('Every Mon, Wed, Fri · 10:00 AM'), findsOneWidget);
      expect(find.text('28 Oct 2026 · 2:30 PM · Paused'), findsOneWidget);

      // Sorted by next occurrence: today 9:30, Mon 26th, Wed 28th.
      final y = [
        'Take medication',
        'Walking exercise',
        'Doctor appointment',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
    });

    testWidgets('fits a 320 px wide phone', (tester) async {
      final (app, _) = await _state([
        _reminder('long', 'A very long reminder title that needs to wrap '
            'onto more than one line',
            frequency: ReminderFrequency.weekly,
            days: ReminderDays.all),
      ]);
      await _pump(tester, app, width: 320);
      expect(tester.takeException(), isNull);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('toggle pauses and resumes; failure restores the switch',
        (tester) async {
      final (app, repository) = await _state(sample);
      await _pump(tester, app);

      Switch switchOf(String id) => tester.widget<Switch>(find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(Switch),
          ));

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('meds')),
          matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(switchOf('meds').value, isFalse);
      expect(app.reminderById('meds')!.isEnabled, isFalse);
      expect(find.text('Every day · 9:30 AM · Paused'), findsOneWidget);
      // Nothing else about the reminder changed.
      expect(app.reminderById('meds')!.frequency, ReminderFrequency.daily);

      repository.fail = true;
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('meds')),
          matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(switchOf('meds').value, isFalse, reason: 'restored');
      expect(find.text('Could not update the reminder. Please try again.'),
          findsOneWidget);
    });

    testWidgets('menu: edit opens the existing reminder', (tester) async {
      final (app, _) = await _state(sample);
      await _pump(tester, app);

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('walk')),
          matching: find.byIcon(Icons.more_vert_rounded)));
      await tester.pumpAndSettle();
      expect(find.text('Edit reminder'), findsOneWidget);
      expect(find.text('Delete reminder'), findsOneWidget);

      await tester.tap(find.text('Edit reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Reminder'), findsOneWidget);
      expect(find.text('Repeat on'), findsOneWidget);
    });

    testWidgets('menu: delete asks first; failure keeps the reminder',
        (tester) async {
      final (app, repository) = await _state(sample);
      await _pump(tester, app);

      Future<void> openDelete() async {
        await tester.tap(find.descendant(
            of: find.byKey(const ValueKey('meds')),
            matching: find.byIcon(Icons.more_vert_rounded)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete reminder'));
        await tester.pumpAndSettle();
        expect(find.text('Delete reminder?'), findsOneWidget);
        expect(
            find.text('Are you sure you want to delete this reminder? '
                'This action cannot be undone.'),
            findsOneWidget);
      }

      await openDelete();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.reminders, hasLength(3));

      repository.fail = true;
      await openDelete();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(app.reminders, hasLength(3));
      expect(find.text('Take medication'), findsOneWidget);
      expect(find.text('Could not delete the reminder. Please try again.'),
          findsOneWidget);

      repository.fail = false;
      await openDelete();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(app.reminders.map((r) => r.id), ['appt', 'walk']);
      expect(find.text('Take medication'), findsNothing);
    });
  });

  test('paused reminders are not offered as the next reminder', () async {
    final (app, _) = await _state(sample);
    expect(app.upcomingReminders.map((r) => r.reminderId),
        isNot(contains('appt')));
  });

  group('Firestore is_enabled', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseDataRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirebaseDataRepository(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: _email),
        ),
      );
    });

    test('missing is_enabled loads as enabled; toggle writes only it',
        () async {
      final doc = firestore
          .collection('patients')
          .doc(_email)
          .collection('reminders')
          .doc('old');
      await doc.set({
        'title': 'Old',
        'frequency': 'Daily',
        'date': null,
        'repeat_days': <String>[],
        'time': '08:00',
        'location': 'Home',
      });

      final data = await repository.loadUserData(
        const Patient(id: _email, fullName: 'P', email: _email),
        isNewAccount: false,
        now: _now,
      );
      expect(data.reminders.single.isEnabled, isTrue);

      await repository.setReminderEnabled('old', false);
      expect((await doc.get()).data(), {
        'title': 'Old',
        'frequency': 'Daily',
        'date': null,
        'repeat_days': <String>[],
        'time': '08:00',
        'location': 'Home',
        'is_enabled': false,
      });

      final reloaded = await repository.loadUserData(
        const Patient(id: _email, fullName: 'P', email: _email),
        isNewAccount: false,
        now: _now,
      );
      expect(reloaded.reminders.single.isEnabled, isFalse);
    });

    test('toggling a reminder that no longer exists fails', () async {
      await expectLater(
        repository.setReminderEnabled('missing', true),
        throwsA(anything),
      );
    });

    test('editing a paused reminder keeps it paused', () async {
      await repository.saveReminder(_reminder('r', 'Walk',
          frequency: ReminderFrequency.daily, enabled: false));
      final doc = await firestore
          .collection('patients')
          .doc(_email)
          .collection('reminders')
          .doc('r')
          .get();
      expect(doc.data()!['is_enabled'], isFalse);
    });
  });
}
