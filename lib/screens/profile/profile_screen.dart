import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/cue_settings.dart';
import '../../models/routine.dart';
import '../../services/auth_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// The "Profile" tab: account details plus links to every setting.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final app = AppScope.read(context);
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign Out?',
      message: 'Are you sure you want to sign out of your ReStep account?',
      confirmLabel: 'Sign Out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed) return;
    await app.signOut();
    navigator.pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final app = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Account?',
      message:
          'Are you sure you want to permanently delete your account? '
          'This action cannot be undone.',
      confirmLabel: 'Delete Account',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed) return;
    try {
      await app.deleteAccount();
    } on ReauthenticationRequiredException {
      // Old session: nothing was deleted. Ask for the password here instead
      // of making the patient sign out and back in.
      if (!context.mounted) return;
      final deleted = await showDialog<bool>(
        context: context,
        barrierColor: AppColors.scrim,
        builder: (_) => _ConfirmPasswordDialog(
          onSubmit: (password) => app.deleteAccount(password: password),
        ),
      );
      if (deleted != true) return;
    } catch (e) {
      messenger.showAppMessage(
        e is AuthException
            ? e.message
            : 'Could not delete your account. Please try again.',
        tone: ChipTone.danger,
      );
      return;
    }
    navigator.pushNamedAndRemoveUntil(Routes.login, (route) => false);
    messenger.showAppMessage(
      'Your account has been deleted',
      tone: ChipTone.success,
    );
  }

  Future<void> _pickReminderDelivery(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReminderDeliverySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final patient = app.patient;
    final theme = Theme.of(context);
    final cue = app.cueSettings;
    final designated = app.designatedContact;

    return TabPage(
      title: 'Profile',
      children: [
        AppCard(
          onTap: () => Navigator.of(context).pushNamed(Routes.editProfile),
          child: Row(
            children: [
              UserAvatar(initials: patient?.initials ?? '?', size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient?.fullName ?? '',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, color: AppColors.navy, size: 26),
            ],
          ),
        ),
        SettingsGroup(
          title: 'Account',
          tiles: [
            SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit profile',
              subtitle: 'Name, email and date of birth',
              onTap: () => Navigator.of(context).pushNamed(Routes.editProfile),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Devices and assistance',
          tiles: [
            SettingsTile(
              icon: Icons.bluetooth_connected_rounded,
              title: 'Devices',
              subtitle: app.pairedDevices.isEmpty
                  ? 'No devices paired yet'
                  : app.isMonitoring
                  ? 'Sensor connected'
                  : 'Sensor not connected',
              onTap: () => Navigator.of(context).pushNamed(Routes.devices),
            ),
            SettingsTile(
              icon: Icons.vibration,
              title: 'Cue settings',
              subtitle: '${cue.type.label} · ${cue.durationSeconds} s',
              onTap: () => Navigator.of(context).pushNamed(Routes.cueSettings),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Notifications & Reminders',
          tiles: [
            SettingsTile(
              icon: Icons.notifications_active_outlined,
              title: 'Reminder delivery',
              subtitle: 'Send reminders to: ${app.reminderPreference.label}',
              onTap: () => _pickReminderDelivery(context),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Safety',
          tiles: [
            SettingsTile(
              icon: Icons.contact_phone_outlined,
              title: 'Emergency contacts',
              subtitle: designated == null
                  ? 'No contact added yet'
                  : 'Designated: ${designated.name}',
              onTap: () =>
                  Navigator.of(context).pushNamed(Routes.emergencyContacts),
            ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Escalation time',
              subtitle: 'Wait ${app.escalation.waitSeconds} s before alerting',
              onTap: () =>
                  Navigator.of(context).pushNamed(Routes.escalationSettings),
            ),
          ],
        ),
        SettingsGroup(
          title: 'About',
          tiles: [
            SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About ReStep and privacy',
              onTap: () => Navigator.of(context).pushNamed(Routes.about),
            ),
            SettingsTile(
              icon: Icons.science_outlined,
              title: 'Prototype demo tools',
              subtitle: 'Simulate detection, reminders and more',
              onTap: () => Navigator.of(context).pushNamed(Routes.demoTools),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SecondaryButton(
          label: 'Sign Out',
          icon: Icons.logout_rounded,
          onPressed: () => _signOut(context),
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Delete Account',
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger,
          onPressed: () => _deleteAccount(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Asks for the patient's password when Firebase needs a recent sign-in to
/// delete the account. Runs [onSubmit] itself so a wrong password can be
/// retried without closing; pops true once the account is deleted.
class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({required this.onSubmit});

  final Future<void> Function(String password) onSubmit;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AuthException
            ? e.message
            : 'Could not delete your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'For your security, enter your password to delete your '
                  'account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  InfoBanner(tone: ChipTone.danger, message: _error!),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.passwordPresent,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                DestructiveButton(
                  label: 'Delete Account',
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Cancel',
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for choosing where reminders are sent (Phone / Smartwatch /
/// Both). Saves immediately through [AppState.setReminderPreference].
class _ReminderDeliverySheet extends StatelessWidget {
  const _ReminderDeliverySheet();

  static IconData _iconOf(ReminderPreference preference) {
    switch (preference) {
      case ReminderPreference.phone:
        return Icons.smartphone_rounded;
      case ReminderPreference.watch:
        return Icons.watch_outlined;
      case ReminderPreference.both:
        return Icons.devices_other_rounded;
    }
  }

  static String _descriptionOf(ReminderPreference preference) {
    switch (preference) {
      case ReminderPreference.phone:
        return 'Reminders appear on this phone';
      case ReminderPreference.watch:
        return 'Reminders go to your paired smartwatch';
      case ReminderPreference.both:
        return 'Reminders go to your phone and smartwatch';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reminder delivery', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Choose where your medication and appointment reminders '
              'are sent.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            for (final preference in ReminderPreference.values)
              OptionTile(
                title: preference.label,
                subtitle: _descriptionOf(preference),
                icon: _iconOf(preference),
                selected: app.reminderPreference == preference,
                onTap: () {
                  app.setReminderPreference(preference);
                  Navigator.of(context).pop();
                },
              ),
            Text(
              'Smartwatch reminders are not available yet. Your choice is '
              'saved and will be used once they are.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
