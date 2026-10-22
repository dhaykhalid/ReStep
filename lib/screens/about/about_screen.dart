import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// About ReStep, what it does not do, and how data is handled.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'About ReStep',
      children: [
        const SizedBox(height: 8),
        const Center(child: ReStepLogo(size: LogoSize.large)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Version ${AppConstants.version}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
        _InfoCard(
          icon: Icons.favorite_border_rounded,
          title: 'What ReStep does',
          lines: const [
            'Monitors your movement using a Shimmer3 IMU sensor.',
            'Detects Freezing of Gait (FoG) episodes in real time.',
            'Provides vibration or auditory cues through your smartwatch to '
                'help you resume movement.',
            'Records FoG episodes and allows you to review your history and '
                'generate reports.',
            'Helps you organize daily activities through personalized '
                'reminders.',
            'Sends an emergency alert with your location to your emergency '
                'contact when predefined conditions are met.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.do_not_disturb_on_outlined,
          title: 'What ReStep does not do',
          lines: const [
            'Does not predict Freezing of Gait (FoG) episodes before they '
                'occur.',
            'Does not provide cueing methods other than vibration and '
                'auditory cues.',
            'Does not provide medical diagnoses, clinical interpretations, or '
                'treatment recommendations.',
            'Does not verify medication dosages or check for drug '
                'interactions.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Your data',
          lines: const [
            'Your personal information and all data stored in ReStep are '
                'protected and accessible only through your account.',
            'Continuous raw sensor data is not permanently stored by default.',
            'Your reports are shared with healthcare professionals only when '
                'you choose to export and share them.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.language_rounded,
          title: 'Language',
          lines: const ['ReStep is currently available in English.'],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Graduation project · King Saud University',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.navy, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 9, right: 10),
                    child: Icon(Icons.circle, size: 7, color: AppColors.sky),
                  ),
                  Expanded(child: Text(line, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
