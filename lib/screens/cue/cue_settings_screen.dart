import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/cue_settings.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Choose a vibration or auditory cue, its pattern and length, and test it.
class CueSettingsScreen extends StatefulWidget {
  const CueSettingsScreen({super.key});

  @override
  State<CueSettingsScreen> createState() => _CueSettingsScreenState();
}

class _CueSettingsScreenState extends State<CueSettingsScreen> {
  late CueSettings _settings;
  late CueSettings _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = AppScope.read(context).cueSettings;
    _settings = _saved;
  }

  Future<void> _test() async {
    await AppScope.read(context).testCue(_settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing your ${_settings.type.label.toLowerCase()} cue'),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await AppScope.read(context).updateCueSettings(_settings);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Cue settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final changed = _settings != _saved;
    return AppScaffold(
      title: 'Cue settings',
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
              loading: _saving,
              onPressed: changed ? _save : null,
            ),
          ),
        ],
      ),
      children: [
        const InfoBanner(
          message: 'When ReStep detects a FoG episode, your cue starts '
              'automatically on your smartwatch.',
        ),
        const SectionHeader(title: 'Cue type', topPadding: 24),
        for (final type in CueType.values)
          OptionTile(
            title: type.label,
            subtitle: type == CueType.vibration
                ? 'Your watch vibrates'
                : 'Your watch plays a sound',
            icon: type.icon,
            selected: _settings.type == type,
            onTap: () => setState(() => _settings = _settings.copyWith(type: type)),
          ),
        const SectionHeader(title: 'Cue pattern', topPadding: 16),
        for (final pattern in CuePattern.values)
          OptionTile(
            title: pattern.label,
            subtitle: pattern == CuePattern.shortConsecutive
                ? 'Repeated short pulses'
                : 'One steady cue until it ends',
            selected: _settings.pattern == pattern,
            onTap: () =>
                setState(() => _settings = _settings.copyWith(pattern: pattern)),
          ),
        const SectionHeader(title: 'Cue length', topPadding: 16),
        SegmentedChoice<int>(
          values: AppConstants.cueDurationOptions,
          labelOf: (v) => '$v s',
          selected: _settings.durationSeconds,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(durationSeconds: v)),
        ),
        const SizedBox(height: 28),
        SecondaryButton(
          label: 'Test My Cue',
          icon: Icons.play_arrow_rounded,
          onPressed: _test,
        ),
      ],
    );
  }
}
