import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Optional Patient-Reported Context check-in after an episode.
/// Ready-made options mean the patient can tap instead of typing.
class ContextCheckInScreen extends StatefulWidget {
  const ContextCheckInScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  State<ContextCheckInScreen> createState() => _ContextCheckInScreenState();
}

class _ContextCheckInScreenState extends State<ContextCheckInScreen> {
  final Set<String> _selected = {};
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final episode = AppScope.read(context).episodeById(widget.episodeId);
    final existing = episode?.context;
    if (existing != null) {
      _selected.addAll(existing.activities);
      _noteController.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final app = AppScope.read(context);
    final note = _noteController.text.trim();
    app.attachContext(
      widget.episodeId,
      EpisodeContext(
        activities: AppConstants.contextOptions
            .where((o) => _selected.contains(o))
            .toList(),
        note: note.isEmpty ? null : note,
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Context saved to your history')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final episode = app.episodeById(widget.episodeId);
    final theme = Theme.of(context);
    final canSave = _selected.isNotEmpty || _noteController.text.trim().isNotEmpty;

    return AppScaffold(
      title: 'Add context',
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
            child: PrimaryButton(
              label: 'Save',
              onPressed: canSave ? _save : null,
            ),
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
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.navy, size: 28),
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in AppConstants.contextOptions)
              FilterPill(
                label: option,
                selected: _selected.contains(option),
                onTap: () => setState(() {
                  if (!_selected.remove(option)) _selected.add(option);
                }),
              ),
          ],
        ),
        const SizedBox(height: 28),
        AppTextField(
          label: 'Anything else? (optional)',
          hint: 'Add a short note',
          controller: _noteController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
