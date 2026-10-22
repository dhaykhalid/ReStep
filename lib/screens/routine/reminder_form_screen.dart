import 'package:flutter/material.dart';

import '../../models/routine.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();

    final app = AppScope.read(context);
    final now = app.now;

    _date = DateTime(now.year, now.month, now.day);

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

  Future<void> _pickDate() async {
    final now = AppScope.read(context).now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final app = AppScope.read(context);

    final reminder = Reminder(
      id: app.newReminderId(),
      title: _titleController.text.trim(),
      context: '',
      date: _date,
      time: _time,
      location: _locationController.text.trim(),
      frequency: 'Once',
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
    messenger.showAppMessage('Reminder added', tone: ChipTone.success);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Add Reminder',
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
                validator: (v) => Validators.required(v, 'Time'),
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
}
