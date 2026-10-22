import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/core/routes/app_routes.dart';
import 'package:restep/screens/about/sensor_data_screen.dart';
import 'package:restep/screens/profile/profile_screen.dart';
import 'package:restep/services/auth_service.dart';
import 'package:restep/services/data_repository.dart';
import 'package:restep/state/app_scope.dart';
import 'package:restep/state/app_state.dart';

void main() {
  testWidgets('Profile: Sensor Data above About, no demo tools',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final app = AppState(
      authService: FirebaseAuthService(
        auth: MockFirebaseAuth(),
        firestore: FakeFirebaseFirestore(),
      ),
      repository: MockDataRepository(),
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

    expect(find.text('Prototype demo tools'), findsNothing);
    expect(find.text('Sensor Data'), findsOneWidget);
    expect(find.text('View real-time Shimmer3 sensor readings'),
        findsOneWidget);

    final sensorY = tester.getTopLeft(find.text('Sensor Data')).dy;
    final aboutY = tester.getTopLeft(find.text('About')).dy;
    final safetyY = tester.getTopLeft(find.text('Safety')).dy;
    expect(sensorY, greaterThan(safetyY));
    expect(sensorY, lessThan(aboutY));

    await tester.tap(find.text('Live sensor data'));
    await tester.pumpAndSettle();
    expect(find.text('route:${Routes.sensorData}'), findsOneWidget);
  });

  testWidgets('the sensor data route opens the existing screen',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }));
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: Routes.sensorData),
    ) as MaterialPageRoute;
    expect(route.builder(context), isA<SensorDataScreen>());
  });
}
