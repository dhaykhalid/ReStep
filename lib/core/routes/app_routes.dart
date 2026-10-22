import 'package:flutter/material.dart';

import '../../screens/about/about_screen.dart';
import '../../screens/about/demo_tools_screen.dart';
import '../../screens/about/sensor_data_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/sign_up_screen.dart';
import '../../screens/cue/active_cue_screen.dart';
import '../../screens/cue/cue_settings_screen.dart';
import '../../screens/devices/devices_screen.dart';
import '../../screens/emergency/contact_form_screen.dart';
import '../../screens/emergency/emergency_contacts_screen.dart';
import '../../screens/emergency/escalation_prompt_screen.dart';
import '../../screens/emergency/escalation_settings_screen.dart';
import '../../screens/history/context_check_in_screen.dart';
import '../../screens/history/episode_detail_screen.dart';
import '../../screens/history/manual_log_screen.dart';
import '../../screens/profile/profile_form_screen.dart';
import '../../screens/reports/report_preview_screen.dart';
import '../../screens/reports/report_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/splash/splash_screen.dart';
import '../../services/report_service.dart';

/// Route names. Screens that need data receive it through `arguments`.
class Routes {
  Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String editProfile = '/edit-profile';
  static const String devices = '/devices';
  static const String cueSettings = '/cue-settings';
  static const String activeCue = '/active-cue';
  static const String episodeDetail = '/episode'; // arguments: String episodeId
  static const String manualLog = '/manual-log';
  static const String contextCheckIn = '/context-check-in'; // String episodeId
  static const String report = '/report';
  static const String reportPreview = '/report-preview'; // ReportResult
  static const String emergencyContacts = '/emergency-contacts';
  static const String contactForm = '/contact-form'; // String? id
  static const String escalationSettings = '/escalation-settings';
  static const String escalationPrompt = '/escalation-prompt';
  static const String about = '/about';
  static const String sensorData = '/sensor-data';

  /// Development only: simulation tools for testing without the hardware.
  /// Not linked from anywhere in the app.
  static const String demoTools = '/demo-tools';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return _route(settings, const SplashScreen());
      case Routes.login:
        return _route(settings, const LoginScreen());
      case Routes.signUp:
        return _route(settings, const SignUpScreen());
      case Routes.forgotPassword:
        return _route(settings, const ForgotPasswordScreen());
      case Routes.home:
        return _route(settings, const MainShell());
      case Routes.editProfile:
        return _route(settings, const ProfileFormScreen());
      case Routes.devices:
        return _route(settings, const DevicesScreen());
      case Routes.cueSettings:
        return _route(settings, const CueSettingsScreen());
      case Routes.activeCue:
        return _route(settings, const ActiveCueScreen());
      case Routes.episodeDetail:
        return _route(
            settings, EpisodeDetailScreen(episodeId: settings.arguments as String));
      case Routes.manualLog:
        return _route(settings, const ManualLogScreen());
      case Routes.contextCheckIn:
        return _route(settings,
            ContextCheckInScreen(episodeId: settings.arguments as String));
      case Routes.report:
        return _route(settings, const ReportScreen());
      case Routes.reportPreview:
        return _route(settings,
            ReportPreviewScreen(report: settings.arguments as ReportResult));

      case Routes.emergencyContacts:
        return _route(settings, const EmergencyContactsScreen());
      case Routes.contactForm:
        return _route(settings,
            ContactFormScreen(contactId: settings.arguments as String?));
      case Routes.escalationSettings:
        return _route(settings, const EscalationSettingsScreen());
      case Routes.escalationPrompt:
        return _route(settings, const EscalationPromptScreen());
      case Routes.about:
        return _route(settings, const AboutScreen());
      case Routes.sensorData:
        return _route(settings, const SensorDataScreen());
      case Routes.demoTools:
        return _route(settings, const DemoToolsScreen());
      default:
        return _route(settings, const SplashScreen());
    }
  }

  static MaterialPageRoute<dynamic> _route(RouteSettings settings, Widget page) {
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }
}
