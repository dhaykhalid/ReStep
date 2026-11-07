import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import 'context_selector.dart';

/// Optional Patient-Reported Context check-in after an episode, also used
/// to edit an episode's context later.
/// Ready-made options mean the patient can tap instead of typing.
class ContextCheckInScreen extends StatefulWidget {
  const ContextCheckInScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  State<ContextCheckInScreen> createState() => _ContextCheckInScreenState();
}

class _ContextCheckInScreenState extends State<ContextCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ContextSelectionController _selection;

  @override
  void initState() {
    super.initState();
    final episode = AppScope.read(context).episodeById(widget.episodeId);
    _selection = ContextSelectionController(episode?.context);
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    // Saving with nothing chosen clears the episode's context.
    app.attachContext(widget.episodeId, _selection.toContext());
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showAppMessage(
      'Context saved to your history',
      tone: ChipTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final episode = app.episodeById(widget.episodeId);
    final theme = Theme.of(context);

    return AppScaffold(
      title: episode?.hasContext ?? false ? 'Edit context' : 'Add context',
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Skip',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(label: 'Save', onPressed: _save),
          ),
        ],
      ),
      children: [
        if (episode != null)
          AppCard(
            color: AppColors.skyTint,
            borderColor: AppColors.skySoft,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.navy,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Episode recorded at ${Fmt.time(episode.startTime)} '
                    '(${Fmt.duration(episode.duration)}).',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('What was happening?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'This is optional. Tap anything that applies.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: ContextSelector(controller: _selection),
        ),
      ],
    );
  }
}
