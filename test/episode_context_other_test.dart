import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/models/fog_episode.dart';
import 'package:restep/models/patient.dart';
import 'package:restep/screens/history/context_check_in_screen.dart';
import 'package:restep/screens/history/manual_log_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

const _email = 'patient@example.com';
// Saturday 24 October 2026, 9:00 AM.
final _now = DateTime(2026, 10, 24, 9);
const _error = 'Please describe what was happening';
final _otherField = find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      w.decoration?.hintText == 'Describe what was happening...',
);

AppState _appState() => AppState(
      authService: FirebaseAuthService(
        auth: MockFirebaseAuth(),
        firestore: FakeFirebaseFirestore(),
      ),
      repository: MockDataRepository(),
      clock: () => _now,
    );

/// Opens [screen] on top of a blank page, so Save can pop it.
Future<void> _open(WidgetTester tester, AppState app, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope(
    state: app,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

FogEpisode _addEpisode(AppState app, [EpisodeContext? context]) =>
    app.addManualEpisode(
      start: _now.subtract(const Duration(hours: 1)),
      duration: const Duration(seconds: 10),
      context: context,
    );

void main() {
  group('Log an episode', () {
    Future<void> openLog(WidgetTester tester, AppState app) async {
      await _open(tester, app, const ManualLogScreen());
      await _tap(tester, '10 s');
    }

    testWidgets('no text box until Other; saves with no context',
        (tester) async {
      final app = _appState();
      await openLog(tester, app);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Note (optional)'), findsNothing);
      expect(find.text('Please specify'), findsNothing);

      await _tap(tester, 'Save');
      expect(app.episodes.single.context, isNull);
    });

    testWidgets('Other needs a description; saved trimmed with others',
        (tester) async {
      final app = _appState();
      await openLog(tester, app);

      await _tap(tester, 'Turning');
      await _tap(tester, 'Other');
      expect(find.text('Please specify'), findsOneWidget);

      await tester.enterText(_otherField, '   ');
      await _tap(tester, 'Save');
      expect(find.text(_error), findsOneWidget);
      expect(app.episodes, isEmpty);

      await tester.enterText(_otherField, '  Walking on an uneven surface ');
      await tester.pump();
      expect(find.text(_error), findsNothing);

      await _tap(tester, 'Save');
      final ctx = app.episodes.single.context!;
      expect(ctx.activities, ['Turning']);
      expect(ctx.otherSituation, 'Walking on an uneven surface');
      expect(ctx.situations,
          ['Turning', 'Other: Walking on an uneven surface']);
    });

    testWidgets('deselecting Other hides the box and clears it',
        (tester) async {
      final app = _appState();
      await openLog(tester, app);

      await _tap(tester, 'Other');
      await tester.enterText(_otherField, 'Old text');
      await _tap(tester, 'Other');
      expect(find.text('Please specify'), findsNothing);

      await _tap(tester, 'Other');
      expect(find.text('Old text'), findsNothing);
      await _tap(tester, 'Other');

      await _tap(tester, 'Save');
      expect(app.episodes.single.context, isNull);
    });
  });

  group('Add / Edit context', () {
    testWidgets('adds Other to an episode; empty Other is rejected',
        (tester) async {
      final app = _appState();
      final episode = _addEpisode(app);
      await _open(tester, app, ContextCheckInScreen(episodeId: episode.id));
      expect(find.text('Add context'), findsOneWidget);
      expect(find.text('Please specify'), findsNothing);

      await _tap(tester, 'Other');
      await _tap(tester, 'Save');
      expect(find.text(_error), findsOneWidget);
      expect(app.episodeById(episode.id)!.hasContext, isFalse);

      await tester.enterText(_otherField, 'Uneven ground');
      await _tap(tester, 'Save');
      expect(app.episodes, hasLength(1));
      expect(app.episodeById(episode.id)!.context!.otherSituation,
          'Uneven ground');
    });

    testWidgets('loads saved Other; deselecting it removes the value',
        (tester) async {
      final app = _appState();
      final episode = _addEpisode(
        app,
        const EpisodeContext(
          activities: ['Turning'],
          note: 'Older note',
          otherSituation: 'Uneven ground',
        ),
      );
      await _open(tester, app, ContextCheckInScreen(episodeId: episode.id));
      expect(find.text('Edit context'), findsOneWidget);
      expect(find.text('Uneven ground'), findsOneWidget);

      await _tap(tester, 'Other');
      await _tap(tester, 'Save');
      final ctx = app.episodeById(episode.id)!.context!;
      expect(ctx.activities, ['Turning']);
      expect(ctx.otherSituation, isNull);
      // An older note has no field any more; it is kept, not erased.
      expect(ctx.note, 'Older note');
    });
  });

  group('Firestore other_situation', () {
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

    Future<List<FogEpisode>> load() async => (await repository.loadUserData(
          const Patient(id: _email, fullName: 'P', email: _email),
          isNewAccount: false,
          now: _now,
        ))
            .episodes;

    Future<Map<String, dynamic>?> contextOf(String id) async =>
        (await firestore
                .collection('patients')
                .doc(_email)
                .collection('fog_episodes')
                .doc(id)
                .get())
            .data()!['context'] as Map<String, dynamic>?;

    FogEpisode episode(EpisodeContext context) => FogEpisode(
          id: 'e1',
          startTime: _now,
          duration: const Duration(seconds: 10),
          source: EpisodeSource.manual,
          context: context,
        );

    test('saved in context, read back, and removed when deselected',
        () async {
      await repository.saveEpisode(episode(const EpisodeContext(
        activities: ['Turning'],
        otherSituation: 'Uneven ground',
      )));
      expect(await contextOf('e1'), {
        'activities': ['Turning'],
        'note': null,
        'other_situation': 'Uneven ground',
      });
      expect((await load()).single.context!.otherSituation, 'Uneven ground');

      // Editing saves the same document without the field.
      await repository.saveEpisode(
          episode(const EpisodeContext(activities: ['Turning'])));
      expect(await contextOf('e1'), {
        'activities': ['Turning'],
        'note': null,
      });
      expect((await load()), hasLength(1));
    });

    test('older episodes without other_situation still load', () async {
      await firestore
          .collection('patients')
          .doc(_email)
          .collection('fog_episodes')
          .doc('old')
          .set({
        'start_time': _now,
        'duration_seconds': 5,
        'source': 'manual',
        'context': {
          'activities': ['Turning'],
          'note': 'Felt tired',
        },
      });

      final ctx = (await load()).single.context!;
      expect(ctx.otherSituation, isNull);
      expect(ctx.situations, ['Turning']);
      expect(ctx.note, 'Felt tired');
    });
  });
}
