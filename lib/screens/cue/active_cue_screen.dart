import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Shown while a cue is running. Stopping takes one press (NFR4).
/// The cue also ends by itself when its configured length is reached.
class ActiveCueScreen extends StatefulWidget {
  const ActiveCueScreen({super.key});

  @override
  State<ActiveCueScreen> createState() => _ActiveCueScreenState();
}

class _ActiveCueScreenState extends State<ActiveCueScreen> {
  Timer? _timer;
  int _elapsed = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cue = AppScope.read(context).activeCue;
      if (cue == null) return;
      setState(() => _elapsed++);
      if (_elapsed >= cue.settings.durationSeconds) {
        _finish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    final app = AppScope.read(context);
    final navigator = Navigator.of(context);
    final episode = await app.finishCue(elapsedSeconds: _elapsed);
    if (!mounted) return;
    if (episode != null && episode.source == EpisodeSource.detected) {
      // Offer the optional Patient-Reported Context check-in.
      navigator.pushReplacementNamed(Routes.contextCheckIn,
          arguments: episode.id);
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cue = app.activeCue;
    final theme = Theme.of(context);

    if (cue == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final total = cue.settings.durationSeconds;
    final int remaining = (total - _elapsed).clamp(0, total).toInt();
    final automatic = cue.source == EpisodeSource.detected;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                const ReStepLogo(size: LogoSize.small),
                const SizedBox(height: 24),
                StatusChip(
                  label: automatic
                      ? 'FoG episode detected'
                      : 'Quick Assistance',
                  tone: ChipTone.info,
                  icon: automatic ? Icons.sensors : Icons.touch_app_rounded,
                ),
                const Spacer(),
                SizedBox(
                  height: 240,
                  width: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 240,
                        width: 240,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 1 : _elapsed / total,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          color: AppColors.navy,
                          backgroundColor: AppColors.skyTint,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cue.settings.type.icon,
                              size: 48, color: AppColors.navy),
                          const SizedBox(height: 8),
                          Text(
                            Fmt.seconds(remaining),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          const Text(
                            'remaining',
                            style: TextStyle(
                                fontSize: 16, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Your ${cue.settings.type.label.toLowerCase()} cue is active',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  automatic
                      ? 'It started automatically. Take your time. '
                          'You can stop it as soon as you are moving again.'
                      : 'You started this cue yourself. You can stop it at '
                          'any time.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.muted),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Stop Cue',
                  icon: Icons.stop_circle_outlined,
                  minHeight: 76,
                  onPressed: _finish,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Also available on your smartwatch.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
