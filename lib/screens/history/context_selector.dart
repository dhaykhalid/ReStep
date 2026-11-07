import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/fog_episode.dart';
import '../../widgets/widgets.dart';

/// What the patient has picked in a [ContextSelector]: any of the
/// ready-made options plus, optionally, "Other" with a description.
class ContextSelectionController extends ChangeNotifier {
  /// Starts from [initial], for example the context being edited.
  ContextSelectionController([EpisodeContext? initial])
      : _note = initial?.note {
    if (initial != null) {
      _selected.addAll(initial.activities);
      _other = initial.hasOther;
      otherText.text = initial.otherSituation?.trim() ?? '';
    }
  }

  final Set<String> _selected = {};
  bool _other = false;
  final String? _note;

  /// The "Please specify" text, used only while [other] is chosen.
  final TextEditingController otherText = TextEditingController();

  bool isSelected(String option) => _selected.contains(option);

  bool get other => _other;

  void toggle(String option) {
    if (!_selected.remove(option)) _selected.add(option);
    notifyListeners();
  }

  /// Turning "Other" off clears its text so it is never saved by mistake.
  void toggleOther() {
    _other = !_other;
    if (!_other) otherText.clear();
    notifyListeners();
  }

  /// The selection as saved on the episode. An older episode's note is
  /// carried over unchanged, since there is no longer a field to edit it.
  EpisodeContext toContext() {
    final other = _other ? otherText.text.trim() : '';
    return EpisodeContext(
      activities: AppConstants.contextOptions
          .where((o) => _selected.contains(o))
          .toList(),
      note: _note,
      otherSituation: other.isEmpty ? null : other,
    );
  }

  @override
  void dispose() {
    otherText.dispose();
    super.dispose();
  }
}

/// The "What was happening?" chips, ending with "Other". Choosing Other
/// shows a required "Please specify" field right under the chips.
/// Place it inside a [Form] so the field is checked on save.
class ContextSelector extends StatelessWidget {
  const ContextSelector({super.key, required this.controller});

  final ContextSelectionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in AppConstants.contextOptions)
                FilterPill(
                  label: option,
                  selected: controller.isSelected(option),
                  onTap: () => controller.toggle(option),
                ),
              FilterPill(
                label: 'Other',
                selected: controller.other,
                onTap: controller.toggleOther,
              ),
            ],
          ),
          if (controller.other) ...[
            const SizedBox(height: 16),
            AppTextField(
              label: 'Please specify',
              hint: 'Describe what was happening...',
              controller: controller.otherText,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Please describe what was happening'
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
