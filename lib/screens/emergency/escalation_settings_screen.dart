import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Set how long ReStep waits for the patient to respond before the
/// designated emergency contact is alerted.
class EscalationSettingsScreen extends StatefulWidget {
  const EscalationSettingsScreen({super.key});

  @override
  State<EscalationSettingsScreen> createState() =>
      _EscalationSettingsScreenState();
}

class _EscalationSettingsScreenState extends State<EscalationSettingsScreen> {
  static const int _min = 10;
  static const int _max = 120;
  static const int _step = 5;

  late int _saved;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _saved = AppScope.read(context).escalation.waitSeconds;
    _seconds = _saved;
  }

  void _change(int delta) {
    setState(() {
      _seconds = (_seconds + delta).clamp(_min, _max).toInt();
    });
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await app.updateEscalation(_seconds);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Saved. This applies to your next episode.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Escalation time',
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: 'Save',
              onPressed: _seconds == _saved ? null : _save,
            ),
          ),
        ],
      ),
      children: [
        Text(
          'Choose how long you have to answer before your designated '
          'contact is alerted.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              _RoundStepButton(
                icon: Icons.remove_rounded,
                label: 'Decrease waiting time',
                onPressed: _seconds > _min ? () => _change(-_step) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_seconds',
                      style: const TextStyle(
                        fontSize: 56,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const Text(
                      'seconds',
                      style: TextStyle(fontSize: 17, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _RoundStepButton(
                icon: Icons.add_rounded,
                label: 'Increase waiting time',
                onPressed: _seconds < _max ? () => _change(_step) : null,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'How it works'),
        const _StepRow(
          number: 1,
          text: 'A FoG episode does not resolve.',
        ),
        const _StepRow(
          number: 2,
          text: 'You see a prompt on your phone and smartwatch with a large '
              '"I\'m Okay" button.',
        ),
        const _StepRow(
          number: 3,
          text: 'If you do not answer in time, a message with the episode '
              'time is sent to your designated contact.',
        ),
        const _StepRow(
          number: 4,
          text: 'If you are safe, you can answer afterwards and a '
              'cancellation message is sent.',
        ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? AppColors.navy : AppColors.border,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: 64,
            width: 64,
            child: Icon(
              icon,
              size: 34,
              color: enabled ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.skyTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}
