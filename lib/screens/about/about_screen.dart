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
            'Version ${AppConstants.version} (prototype)',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
        _InfoCard(
          icon: Icons.favorite_border_rounded,
          title: 'What ReStep does',
          lines: const [
            'Monitors your movement with a Shimmer3 IMU sensor.',
            'Detects Freezing of Gait (FoG) episodes as they occur.',
            'Delivers your vibration or auditory cue on your smartwatch.',
            'Records your episodes so you can review them and share a '
                'FoG report if you choose.',
            'Helps you manage medications and appointments, and can alert '
                'your emergency contact.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.do_not_disturb_on_outlined,
          title: 'What ReStep does not do',
          lines: const [
            'It detects episodes as they happen. It does not predict them.',
            'It shows vibration and auditory cues only.',
            'It shows recorded episodes without clinical interpretation. It '
                'gives no diagnosis or treatment recommendations.',
            'It does not check medication doses or interactions.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Your data',
          lines: const [
            'Your FoG information is stored securely and is only available '
                'to your account.',
            'Continuous raw sensor data is not permanently kept by default.',
            'Reports are shared with a healthcare professional only when you '
                'choose to export and share them.',
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.language_rounded,
          title: 'Language',
          lines: const ['The app is currently available in English.'],
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
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
