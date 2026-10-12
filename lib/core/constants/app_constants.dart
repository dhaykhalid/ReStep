/// Asset paths used across the app.
class AppAssets {
  AppAssets._();

  /// Place your real ReStep logo at this exact path.
  static const String logo = 'assets/images/restep_logo.png';
}

/// General constants (labels, demo credentials, option lists).
class AppConstants {
  AppConstants._();

  static const String appName = 'ReStep';
  static const String version = '1.0.0';

  /// Prototype-only demo account (see MockAuthService).
  static const String demoEmail = 'demo@restep.app';
  static const String demoPassword = 'Restep123';

  /// Ready-made options for Patient-Reported Context, so patients can tap
  /// instead of typing (requested in the interviews).
  static const List<String> contextOptions = [
    'Starting to walk',
    'Turning',
    'Passing a doorway',
    'Narrow or crowded space',
    'Carrying something',
    'Standing still',
    'Feeling tired',
    'Feeling stressed or in a hurry',
  ];

  static const List<int> cueDurationOptions = [10, 20, 30];
}
