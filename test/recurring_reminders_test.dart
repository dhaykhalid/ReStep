import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/models/patient.dart';
import 'package:restep/models/routine.dart';
import 'package:restep/screens/routine/reminder_form_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

const _email = 'patient@example.com';
// Saturday 24 October 2026, 9:00 AM.
final _now = DateTime(2026, 10, 24, 9);
const _ten = TimeOfDay(hour: 10, minute: 0);

AppState _appState() => AppState(
      authService: FirebaseAuthService(
        auth: MockFirebaseAuth(),
        firestore: FakeFirebaseFirestore(),
      ),
      repository: MockDataRepository(),
      clock: () => _now,
    );

Reminder _reminder({
  String id = 'r1',
  ReminderFrequency frequency = ReminderFrequency.once,
  DateTime? date,
  List<String> days = const [],
  TimeOfDay time = _ten,
  String location = '',
}) =>
    Reminder(
      id: id,
      title: 'Walk',
      frequency: frequency,
      date: date,
      repeatDays: days,
      time: time,
      location: location,
    );

void main() {
  group('Reminder model', () {
    test('schedule labels', () {
      expect(
        _reminder(date: DateTime(2026, 10, 24)).scheduleLabel,
        '24 Oct 2026 · 10:00 AM',
      );
      expect(
        _reminder(frequency: ReminderFrequency.daily).scheduleLabel,
        'Every day · 10:00 AM',
      );
      expect(
        _reminder(
          frequency: ReminderFrequency.weekly,
          days: ['Sun', 'Tue', 'Thu'],
        ).scheduleLabel,
        'Every Sun, Tue, Thu · 10:00 AM',
      );
    });

    test('daily: today if still ahead, otherwise tomorrow', () {
      final daily = _reminder(frequency: ReminderFrequency.daily);
      expect(daily.nextOccurrence(_now), DateTime(2026, 10, 24, 10));
      expect(daily.nextOccurrence(DateTime(2026, 10, 24, 11)),
          DateTime(2026, 10, 25, 10));
    });

    test('weekly: only on the selected days', () {
      final weekly = _reminder(
        frequency: ReminderFrequency.weekly,
        days: ['Sun', 'Tue', 'Thu'],
      );
      // Saturday -> Sunday 25th.
      expect(weekly.nextOccurrence(_now), DateTime(2026, 10, 25, 10));
      // Sunday after 10:00 -> Tuesday 27th.
      expect(weekly.nextOccurrence(DateTime(2026, 10, 25, 12)),
          DateTime(2026, 10, 27, 10));
      // Same weekday next week when today's time has passed.
      final saturdays =
          _reminder(frequency: ReminderFrequency.weekly, days: ['Sat']);
      expect(saturdays.nextOccurrence(DateTime(2026, 10, 24, 11)),
          DateTime(2026, 10, 31, 10));
      expect(_reminder(frequency: ReminderFrequency.weekly).nextOccurrence(_now),
          isNull);
    });

    test('once: its own date and time', () {
      expect(_reminder(date: DateTime(2026, 11, 2)).nextOccurrence(_now),
          DateTime(2026, 11, 2, 10));
    });

    test('frequency and day parsing tolerate old or odd values', () {
      expect(ReminderFrequencyX.fromFirestore(null), ReminderFrequency.once);
      expect(ReminderFrequencyX.fromFirestore('daily'), ReminderFrequency.daily);
      expect(
          ReminderFrequencyX.fromFirestore('Weekly'), ReminderFrequency.weekly);
      expect(ReminderDays.normalize(['thu', 'Sunday', 'Tue', 'Tue', 3, 'x']),
          ['Sun', 'Tue', 'Thu']);
    });
  });

  group('Firestore reminders', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseDataRepository repository;
    late DocumentReference<Map<String, dynamic>> doc;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirebaseDataRepository(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: _email),
        ),
      );
      doc = firestore
          .collection('patients')
          .doc(_email)
          .collection('reminders')
          .doc('r1');
    });

    test('saves each repeat option with only its own values', () async {
      await repository.saveReminder(
          _reminder(date: DateTime(2026, 10, 30), location: 'Clinic'));
      expect((await doc.get()).data(), {
        'title': 'Walk',
        'frequency': 'Once',
        'date': Timestamp.fromDate(DateTime(2026, 10, 30)),
        'repeat_days': <String>[],
        'time': '10:00',
        'location': 'Clinic',
        'is_enabled': true,
      });

      // Once -> Weekly clears the date.
      await repository.saveReminder(_reminder(
        frequency: ReminderFrequency.weekly,
        days: ['Sun', 'Tue', 'Thu'],
        time: const TimeOfDay(hour: 18, minute: 5),
      ));
      expect((await doc.get()).data(), {
        'title': 'Walk',
        'frequency': 'Weekly',
        'date': null,
        'repeat_days': ['Sun', 'Tue', 'Thu'],
        'time': '18:05',
        'location': '',
        'is_enabled': true,
      });

      // Weekly -> Daily clears the days.
      await repository
          .saveReminder(_reminder(frequency: ReminderFrequency.daily));
      final daily = (await doc.get()).data()!;
      expect(daily['frequency'], 'Daily');
      expect(daily['date'], isNull);
      expect(daily['repeat_days'], isEmpty);
    });

    test('updating an old reminder removes context; old docs still load',
        () async {
      await doc.set({
        'title': 'Old reminder',
        'context': 'Medication',
        'date': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'time': '08:30',
        'location': '',
        'frequency': 'Once',
      });

      final data = await repository.loadUserData(
        const Patient(id: _email, fullName: 'P', email: _email),
        isNewAccount: false,
        now: _now,
      );
      final loaded = data.reminders.single;
      expect(loaded.frequency, ReminderFrequency.once);
      expect(loaded.date, DateTime(2026, 11, 1));
      expect(loaded.repeatDays, isEmpty);
      expect(loaded.time, const TimeOfDay(hour: 8, minute: 30));

      await repository.saveReminder(_reminder(
        frequency: ReminderFrequency.daily,
        time: loaded.time,
      ));
      final updated = (await doc.get()).data()!;
      expect(updated.containsKey('context'), isFalse);
      expect(updated['date'], isNull);
      expect(updated['frequency'], 'Daily');
    });

    test('a weekly doc without repeat_days loads with no days', () async {
      await doc.set({'title': 'T', 'frequency': 'Weekly', 'time': '09:00'});
      final data = await repository.loadUserData(
        const Patient(id: _email, fullName: 'P', email: _email),
        isNewAccount: false,
        now: _now,
      );
      expect(data.reminders.single.repeatDays, isEmpty);
      expect(data.reminders.single.date, isNull);
    });
  });

  group('Reminder form', () {
    Future<AppState> pumpForm(WidgetTester tester,
        {Reminder? existing}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final app = _appState();
      if (existing != null) await app.saveReminder(existing);
      await tester.pumpWidget(AppScope(
        state: app,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReminderFormScreen(reminderId: existing?.id),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return app;
    }

    Finder labelled(String label) => find.text(label);

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('fields follow the Repeat option', (tester) async {
      await pumpForm(tester);
      expect(find.text('Add Reminder'), findsOneWidget);

      // Default: Does not repeat -> Date shown, no weekdays.
      expect(labelled('Date'), findsOneWidget);
      expect(labelled('Repeat on'), findsNothing);

      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();
      expect(labelled('Date'), findsNothing);
      expect(labelled('Repeat on'), findsNothing);
      expect(labelled('Time'), findsOneWidget);

      await tester.tap(find.text('Weekly (select days)'));
      await tester.pumpAndSettle();
      expect(labelled('Date'), findsNothing);
      expect(labelled('Repeat on'), findsOneWidget);
      for (final day in ReminderDays.all) {
        expect(find.text(day), findsOneWidget);
      }
      expect(labelled('Location'), findsOneWidget);
    });

    testWidgets('weekly needs a day; saves the selected days', (tester) async {
      final app = await pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Physio');
      await tester.tap(find.text('Weekly (select days)'));
      await tester.pumpAndSettle();

      await save(tester);
      expect(find.text('Select at least one day'), findsOneWidget);
      expect(app.reminders, isEmpty);

      await tester.tap(find.text('Thu'));
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      expect(find.text('Select at least one day'), findsNothing);

      await save(tester);
      final saved = app.reminders.single;
      expect(saved.frequency, ReminderFrequency.weekly);
      expect(saved.repeatDays, ['Sun', 'Thu']);
      expect(saved.date, isNull);
      expect(saved.title, 'Physio');
    });

    testWidgets('a one-time reminder cannot be in the past', (tester) async {
      final app = await pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Call');
      // Default is today 10:00, which is still ahead of 9:00: valid.
      expect(find.text('24 Oct 2026'), findsOneWidget);

      await save(tester);
      expect(app.reminders.single.date, DateTime(2026, 10, 24));
      expect(app.reminders.single.frequency, ReminderFrequency.once);
    });

    testWidgets('an existing reminder past today is rejected until changed',
        (tester) async {
      final app = await pumpForm(
        tester,
        existing: _reminder(
          date: DateTime(2026, 10, 24),
          time: const TimeOfDay(hour: 8, minute: 0),
        ),
      );
      await save(tester);
      expect(find.text('Choose a time later than now'), findsOneWidget);
      expect(app.reminders.single.time, const TimeOfDay(hour: 8, minute: 0));

      // Switching to Every day makes the same time valid.
      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a time later than now'), findsNothing);
      await save(tester);
      expect(app.reminders.single.frequency, ReminderFrequency.daily);
      expect(app.reminders.single.date, isNull);
    });

    testWidgets('edit loads the saved settings and updates in place',
        (tester) async {
      final app = await pumpForm(
        tester,
        existing: _reminder(
          frequency: ReminderFrequency.weekly,
          days: ['Mon', 'Fri'],
          location: 'Gym',
        ),
      );
      expect(find.text('Edit Reminder'), findsOneWidget);
      expect(labelled('Repeat on'), findsOneWidget);
      expect(labelled('Date'), findsNothing);
      expect(find.text('Gym'), findsOneWidget);

      final radio = tester.widget<RadioGroup<ReminderFrequency>>(
          find.byType(RadioGroup<ReminderFrequency>));
      expect(radio.groupValue, ReminderFrequency.weekly);

      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(app.reminders, hasLength(1), reason: 'no duplicate');
      expect(app.reminders.single.id, 'r1');
      expect(app.reminders.single.repeatDays, ['Mon', 'Wed', 'Fri']);
      expect(find.text('Reminder updated'), findsOneWidget);
    });
  });

  test('upcoming list orders by next occurrence and handles null dates',
      () async {
    final app = _appState();
    await app.saveReminder(_reminder(
        id: 'once', date: DateTime(2026, 10, 26), location: 'Clinic'));
    await app.saveReminder(_reminder(
        id: 'daily',
        frequency: ReminderFrequency.daily,
        time: const TimeOfDay(hour: 9, minute: 30)));
    await app.saveReminder(_reminder(
        id: 'weekly', frequency: ReminderFrequency.weekly, days: ['Sun']));

    final upcoming = app.upcomingReminders;
    expect(upcoming.map((r) => r.reminderId), ['daily', 'weekly', 'once']);
    expect(upcoming.first.schedule, 'Every day · 9:30 AM');

    // Dismissing today's daily occurrence moves it to tomorrow.
    app.dismissReminder(upcoming.first.key);
    final daily =
        app.upcomingReminders.firstWhere((r) => r.reminderId == 'daily');
    expect(daily.when, DateTime(2026, 10, 25, 9, 30));
  });
}
