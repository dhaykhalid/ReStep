import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/routine.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Add a reminder, or edit one when [reminderId] is given.
///
/// The fields follow the Repeat option: a one-time reminder has a date,
/// a daily reminder only a time, and a weekly reminder its days and a time.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.reminderId});

  final String? reminderId;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  static const _errorStyle = TextStyle(
    fontSize: 14,
    height: 1.3,
    color: AppColors.danger,
    fontWeight: FontWeight.w600,
  );

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();

  Reminder? _existing;
  ReminderFrequency _frequency = ReminderFrequency.once;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  final Set<String> _days = {};

  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();

    final app = AppScope.read(context);
    final now = app.now;
    final today = Fmt.dayOnly(now);

    final id = widget.reminderId;
    final existing = id == null ? null : app.reminderById(id);
    _existing = existing;

    if (existing != null) {
      _titleController.text = existing.title;
      _locationController.text = existing.location;
      _frequency = existing.frequency;
      _time = existing.time;
      _days.addAll(existing.repeatDays);
    }

    final savedDate = existing?.date;
    if (savedDate != null) {
      _date = Fmt.dayOnly(savedDate);
    } else {
      // Today, or tomorrow if the default time has already passed.
      final todayAtTime =
          DateTime(today.year, today.month, today.day, _time.hour, _time.minute);
      _date = todayAtTime.isAfter(now) ? today : Fmt.addDays(today, 1);
    }
    _dateController.text = Fmt.date(_date);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timeController.text = _time.format(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime get _today => Fmt.dayOnly(AppScope.read(context).now);

  Future<void> _pickDate() async {
    final today = _today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: 'Reminder date',
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
      helpText: 'Reminder time',
    );

    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  String? _validateDate(String? value) {
    final required = Validators.required(value, 'Date');
    if (required != null) return required;
    if (_date.isBefore(_today)) return 'Choose today or a later date';
    return null;
  }

  String? _validateTime(String? value) {
    final required = Validators.required(value, 'Time');
    if (required != null) return required;
    // A one-time reminder cannot be set for earlier today.
    if (_frequency == ReminderFrequency.once &&
        Fmt.sameDay(_date, _today)) {
      final at = DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute);
      if (at.isBefore(AppScope.read(context).now)) {
        return 'Choose a time later than now';
      }
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final app = AppScope.read(context);

    final reminder = Reminder(
      id: _existing?.id ?? app.newReminderId(),
      title: _titleController.text.trim(),
      frequency: _frequency,
      // Only the values for the chosen option are kept.
      date: _frequency == ReminderFrequency.once ? _date : null,
      repeatDays: _frequency == ReminderFrequency.weekly
          ? [for (final day in ReminderDays.all) if (_days.contains(day)) day]
          : const [],
      time: _time,
      location: _locationController.text.trim(),
      // New reminders start enabled; editing keeps the current state.
      isEnabled: _existing?.isEnabled ?? true,
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await app.saveReminder(reminder);
    } catch (_) {
      messenger.showAppMessage(
        'Could not save the reminder. Please try again.',
        tone: ChipTone.danger,
      );
      return;
    }

    if (!mounted) return;

    navigator.pop();
    messenger.showAppMessage(
      _isEditing ? 'Reminder updated' : 'Reminder added',
      tone: ChipTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: _isEditing ? 'Edit Reminder' : 'Add Reminder',
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
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Reminder',
                hint: 'For example Take medication',
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.notifications_none_rounded,
                validator: (v) => Validators.required(v, 'Reminder'),
              ),
              const SizedBox(height: 20),
              Text('Repeat', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _RepeatOptions(
                value: _frequency,
                onChanged: (value) => setState(() => _frequency = value),
              ),
              const SizedBox(height: 20),
              if (_frequency == ReminderFrequency.once) ...[
                AppTextField(
                  label: 'Date',
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  prefixIcon: Icons.calendar_today_outlined,
                  validator: _validateDate,
                ),
                const SizedBox(height: 20),
              ],
              if (_frequency == ReminderFrequency.weekly) ...[
                _buildDays(theme),
                const SizedBox(height: 20),
              ],
              AppTextField(
                label: 'Time',
                controller: _timeController,
                readOnly: true,
                onTap: _pickTime,
                prefixIcon: Icons.access_time_rounded,
                validator: _validateTime,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Location',
                hint: 'Optional',
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.place_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Weekday chips. At least one day is required; the message appears on
  /// Save and clears as soon as a day is selected.
  Widget _buildDays(ThemeData theme) {
    return FormField<Set<String>>(
      initialValue: {..._days},
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (days) =>
          days == null || days.isEmpty ? 'Select at least one day' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Repeat on', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in ReminderDays.all)
                FilterPill(
                  label: day,
                  selected: _days.contains(day),
                  onTap: () {
                    setState(() {
                      if (!_days.remove(day)) _days.add(day);
                    });
                    field.didChange({..._days});
                  },
                ),
            ],
          ),
          if (field.hasError) ...[
            const SizedBox(height: 8),
            Text(field.errorText!, style: _errorStyle),
          ],
        ],
      ),
    );
  }
}

/// The three Repeat choices as radio buttons, styled like the form fields.
class _RepeatOptions extends StatelessWidget {
  const _RepeatOptions({required this.value, required this.onChanged});

  final ReminderFrequency value;
  final ValueChanged<ReminderFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RadioGroup<ReminderFrequency>(
      groupValue: value,
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
      child: Material(
        color: AppColors.fieldFill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            for (final option in ReminderFrequency.values)
              RadioListTile<ReminderFrequency>(
                value: option,
                title: Text(option.label, style: theme.textTheme.bodyLarge),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.navy
                      : AppColors.muted,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
          ],
        ),
      ),
    );
  }
}
