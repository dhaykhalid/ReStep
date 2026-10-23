
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Add, edit and remove emergency contacts, and choose which one is designated.
class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final contacts = app.contacts;

    return AppScaffold(
      title: 'Emergency Contacts',
      children: [
    const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Text(
    'Your designated contact receives a message if a FoG episode '
    'does not resolve and you do not respond. They do not need the '
    'ReStep app.',
    style: TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.muted,
    ),
    ),
    ),
        const SizedBox(height: 20),

        // Enable / disable Emergency Contacts.
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_phone_outlined,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.emergencyContactsEnabled
                          ? 'Emergency alerts are enabled'
                          : 'Emergency alerts are disabled',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: app.emergencyContactsEnabled,
                onChanged: (enabled) async {
                  if (enabled && contacts.isEmpty) {
                    ScaffoldMessenger.of(context).showAppMessage(
                      'Please add an emergency contact to enable emergency alerts.',
                    );
                    return;
                  }

                  try {
                    await app.setEmergencyContactsEnabled(enabled);
                  } catch (_) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not update Emergency Contacts. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                activeTrackColor: AppColors.navy,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        PrimaryButton(
          label: 'Add Contact',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () {
            Navigator.of(context).pushNamed(Routes.contactForm);
          },
        ),

        const SizedBox(height: 16),

        if (contacts.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.contact_phone_outlined,
              title: 'No emergency contacts yet',
              message:
              'Add a person who should be told if you need help.',
            ),
          )
        else
          for (final contact in contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    Routes.contactForm,
                    arguments: contact.id,
                  );
                },
                child: Row(
                  children: [
                    UserAvatar(
                      initials: contact.name.trim().isEmpty
                          ? '?'
                          : contact.name
                          .trim()
                          .substring(0, 1)
                          .toUpperCase(),
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contact.phone,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.muted,
                            ),
                          ),
                          if (contact.isDesignated) ...[
                            const SizedBox(height: 8),
                            const StatusChip(
                              label: 'Designated',
                              tone: ChipTone.success,
                              icon: Icons.verified_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
