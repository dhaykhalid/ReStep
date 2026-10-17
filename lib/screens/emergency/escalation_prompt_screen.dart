import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/emergency.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

enum _PromptStage { asking, alertSent, noContact }

/// "Are you alright?" prompt for an episode that does not resolve.
/// Shown on the phone (and the smartwatch). If the patient does not answer in
/// time, the designated emergency contact receives an SMS with the episode time.
class EscalationPromptScreen extends StatefulWidget {
  const EscalationPromptScreen({super.key});

  @override
  State<EscalationPromptScreen> createState() => _EscalationPromptScreenState();
}

class _EscalationPromptScreenState extends State<EscalationPromptScreen> {
  static const int _episodeSecondsBeforePrompt = 30;

  Timer? _timer;
  late final int _waitSeconds;
  int _remaining = 0;
  _PromptStage _stage = _PromptStage.asking;
  String? _episodeId;
  EmergencyContact? _alerted;

  @override
  void initState() {
    super.initState();
    _waitSeconds = AppScope.read(context).escalation.waitSeconds;
    _remaining = _waitSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTimeout() {
    _timer?.cancel();
    final app = AppScope.read(context);
    final contact = app.designatedContact;
    final episode = app.recordEscalatedEpisode(
      durationSeconds: _episodeSecondsBeforePrompt + _waitSeconds,
      alertedContact: contact,
    );
    setState(() {
      _episodeId = episode.id;
      _alerted = contact;
      _stage = contact == null
          ? _PromptStage.noContact
          : _PromptStage.alertSent;
    });
  }

  /// "I'm okay" pressed before the time ran out: the episode closes, no alert.
  void _confirmOkay() {
    _timer?.cancel();
    final app = AppScope.read(context);
    final elapsed = _waitSeconds - _remaining;
    final episode = app.recordEscalatedEpisode(
      durationSeconds: _episodeSecondsBeforePrompt + elapsed,
    );
    Navigator.of(context)
        .pushReplacementNamed(Routes.contextCheckIn, arguments: episode.id);
  }

  /// "I'm okay" pressed after the alert was sent: a cancellation message is sent.
  void _cancelAlert() {
    final app = AppScope.read(context);
    final id = _episodeId;
    if (id != null) app.markAlertCancelled(id);
    final messenger = ScaffoldMessenger.of(context);
    final name = _alerted?.name ?? 'your contact';
    Navigator.of(context).pop();
    messenger.showAppMessage(
      'Cancellation message sent to $name',
      tone: ChipTone.success,
    );
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _buildStage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppScope.of(context);

    switch (_stage) {
      case _PromptStage.asking:
        final contact = app.designatedContact;
        return Column(
          children: [
            const ReStepLogo(size: LogoSize.small),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Your FoG episode has not resolved',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Are you alright?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: CircularProgressIndicator(
                      value: _waitSeconds == 0 ? 0 : _remaining / _waitSeconds,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      color: AppColors.navy,
                      backgroundColor: AppColors.skyTint,
                    ),
                  ),
                  Text(
                    '${_remaining < 0 ? 0 : _remaining}',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              contact == null
                  ? 'This prompt is also shown on your smartwatch.'
                  : 'If you do not answer, ${contact.name} will receive a '
                        'message. This prompt is also shown on your smartwatch.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: "I'm Okay",
              icon: Icons.check_circle_outline_rounded,
              minHeight: 88,
              onPressed: _confirmOkay,
            ),
          ],
        );

      case _PromptStage.alertSent:
        return Column(
          children: [
            const ReStepLogo(size: LogoSize.small),
            const Spacer(),
            Container(
              height: 96,
              width: 96,
              decoration: const BoxDecoration(
                color: AppColors.warningTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sms_outlined,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your contact has been alerted',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'A message with the time of your episode was sent to '
              '${_alerted?.name ?? 'your contact'} at '
              '${Fmt.time(app.now)}. The alert is saved in your history.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const InfoBanner(
              message:
                  'If you are safe, press the button below and we will '
                  'send a message to let them know.',
            ),
            const Spacer(),
            PrimaryButton(
              label: "I'm Okay, Let Them Know",
              icon: Icons.check_circle_outline_rounded,
              minHeight: 88,
              onPressed: _cancelAlert,
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: _close, child: const Text('Close')),
          ],
        );

      case _PromptStage.noContact:
        return Column(
          children: [
            const ReStepLogo(size: LogoSize.small),
            const Spacer(),
            Container(
              height: 96,
              width: 96,
              decoration: const BoxDecoration(
                color: AppColors.warningTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No emergency contact set',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'No message could be sent because you have not added an '
              'emergency contact yet. Add one so help can reach you next time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Add Emergency Contact',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: () {
                Navigator.of(context)
                    .pushReplacementNamed(Routes.emergencyContacts);
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(label: "I'm Okay", onPressed: _close),
          ],
        );
    }
  }
}
