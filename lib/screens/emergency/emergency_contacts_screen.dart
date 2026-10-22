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
      title: 'Emergency contacts',
      children: [
        const InfoBanner(
          message:
              'Your designated contact receives a message if a FoG '
              'episode does not resolve and you do not respond. They do not '
              'need the ReStep app.',
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Add Contact',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () => Navigator.of(context).pushNamed(Routes.contactForm),
        ),
        const SizedBox(height: 16),
        if (contacts.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.contact_phone_outlined,
              title: 'No emergency contacts yet',
              message: 'Add a person who should be told if you need help.',
            ),
          )
        else
          for (final contact in contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                onTap: () =>
                    Navigator.of(context)
                        .pushNamed(Routes.contactForm, arguments: contact.id),
                child: Row(
                  children: [
                    UserAvatar(
                      initials: contact.name.trim().isEmpty
                          ? '?'
                          : contact.name.trim().substring(0, 1).toUpperCase(),
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
