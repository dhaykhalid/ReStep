import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/shimmer_device_service.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

class ReStepApp extends StatefulWidget {
  const ReStepApp({super.key, this.appState});

  /// Optional: inject a pre-built state (used by tests).
  final AppState? appState;

  @override
  State<ReStepApp> createState() => _ReStepAppState();
}

class _ReStepAppState extends State<ReStepApp> {
  late final AppState _state = widget.appState ??
      AppState(deviceService: ShimmerDeviceService());

  @override
  void dispose() {
    if (widget.appState == null) {
      _state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: Routes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) {
          // Respect the phone's text size setting, but cap extreme values so
          // layouts stay usable.
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler
                  .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
