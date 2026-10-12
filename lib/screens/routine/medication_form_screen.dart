import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Add or edit a medication (name, dose, time). Pass [medicationId] to edit.
class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key, this.medicationId});

  final String? medicationId;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _timeController = TextEditingController();
  Medication? _existing;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    for (final m in app.medications) {
      if (m.id == widget.medicationId) _existing = m;
    }
    final existing = _existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _doseController.text = existing.dose;
      _time = existing.time;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timeController.text = _time.format(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Time to take it',
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
    app.saveMedication(Medication(
      id: _existing?.id ?? app.newMedicationId(),
      name: _nameController.text.trim(),
      dose: _doseController.text.trim(),
      time: _time,
    ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Medication saved')),
    );
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete medication?',
      message: 'This medication and its reminder will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    app.deleteMedication(_existing!.id);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Medication deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'Edit medication' : 'Add medication',
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
                label: 'Medication name',
                hint: 'For example Levodopa/Carbidopa',
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.medication_outlined,
                validator: (v) => Validators.required(v, 'Medication name'),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Dose',
                hint: 'For example 1 tablet (100/25 mg)',
                controller: _doseController,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.scale_outlined,
                validator: (v) => Validators.required(v, 'Dose'),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        const InfoBanner(
          message: 'ReStep saves what you enter. It does not check doses or '
              'interactions.',
        ),
        if (_isEditing) ...[
          const SizedBox(height: 28),
          SecondaryButton(
            label: 'Delete Medication',
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
