import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cue_settings.dart';
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
      message: 'Are you sure you want to permanently delete your account? '
          'This action cannot be undone.',
      confirmLabel: 'Delete Account',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed) return;
    await app.deleteAccount();
    navigator.pushNamedAndRemoveUntil(Routes.login, (route) => false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted')),
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
                    Text(patient?.fullName ?? '',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      patient?.email ?? '',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
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
              subtitle: 'Name, email, phone and date of birth',
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
