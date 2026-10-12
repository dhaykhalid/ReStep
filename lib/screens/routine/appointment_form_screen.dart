import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Add or edit a medical appointment (title, date, time, location).
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, this.appointmentId});

  final String? appointmentId;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  Appointment? _existing;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    final now = app.now;
    _date = DateTime(now.year, now.month, now.day + 1);
    for (final a in app.appointments) {
      if (a.id == widget.appointmentId) _existing = a;
    }
    final existing = _existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _locationController.text = existing.location;
      _date = existing.date;
      _time = existing.time;
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
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = AppScope.read(context).now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Appointment date',
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
      helpText: 'Appointment time',
    );
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    app.saveAppointment(Appointment(
      id: _existing?.id ?? app.newAppointmentId(),
      title: _titleController.text.trim(),
      date: _date,
      time: _time,
      location: _locationController.text.trim(),
    ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Appointment saved')),
    );
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete appointment?',
      message: 'This appointment and its reminder will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    app.deleteAppointment(_existing!.id);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Appointment deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'Edit appointment' : 'Add appointment',
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: PrimaryButton(label: 'Save', onPressed: _save)),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Appointment',
                hint: 'For example Neurology follow-up',
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.event_note_outlined,
                validator: (v) => Validators.required(v, 'Appointment'),
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
                hint: 'Hospital or clinic',
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.place_outlined,
                validator: (v) => Validators.required(v, 'Location'),
              ),
            ],
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 28),
          SecondaryButton(
            label: 'Delete Appointment',
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
