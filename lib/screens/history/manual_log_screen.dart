import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Manual FoG Logging: add an episode ReStep did not capture.
class ManualLogScreen extends StatefulWidget {
  const ManualLogScreen({super.key});

  @override
  State<ManualLogScreen> createState() => _ManualLogScreenState();
}

class _ManualLogScreenState extends State<ManualLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _durationController = TextEditingController();
  final _noteController = TextEditingController();
  final Set<String> _selected = {};
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  static const List<int> _quickDurations = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    final now = AppScope.read(context).now;
    _date = Fmt.dayOnly(now);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
    _dateController.text = Fmt.date(_date);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs a BuildContext for TimeOfDay.format.
    _timeController.text = _time.format(context);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = AppScope.read(context).now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: Fmt.dayOnly(now),
      helpText: 'Date of the episode',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = Fmt.date(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Time of the episode',
    );
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  String? _validateDateTime(String? _) {
    final now = AppScope.read(context).now;
    final start =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (start.isAfter(now)) {
      return 'The episode time cannot be in the future';
    }
    return null;
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    final seconds = int.parse(_durationController.text.trim());
    final note = _noteController.text.trim();
    app.addManualEpisode(
      start:
          DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
      duration: Duration(seconds: seconds),
      context: EpisodeContext(
        activities: AppConstants.contextOptions
            .where((o) => _selected.contains(o))
            .toList(),
        note: note.isEmpty ? null : note,
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Episode added to your history')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Log an episode',
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
            child: PrimaryButton(label: 'Save', onPressed: _save),
          ),
        ],
      ),
      children: [
        Text(
          'Add an episode that ReStep did not capture. It will be marked as '
          'added manually.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Date',
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                prefixIcon: Icons.calendar_today_outlined,
                validator: (v) => Validators.required(v, 'Date'),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Time',
                controller: _timeController,
                readOnly: true,
                onTap: _pickTime,
                prefixIcon: Icons.access_time_rounded,
                validator: _validateDateTime,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Duration (seconds)',
                hint: 'For example 10',
                controller: _durationController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixIcon: Icons.timer_outlined,
                validator: Validators.durationSeconds,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in _quickDurations)
                    FilterPill(
                      label: Fmt.seconds(s),
                      selected: _durationController.text == '$s',
                      onTap: () => setState(() {
                        _durationController.text = '$s';
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text('What was happening? (optional)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
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
              const SizedBox(height: 20),
              AppTextField(
                label: 'Note (optional)',
                hint: 'Add a short note',
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
