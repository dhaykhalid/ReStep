import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/patient.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Edit profile, and also the "profile setup" step shown right after
/// registration ([isSetup] = true).
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, this.isSetup = false});

  final bool isSetup;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _dobController;

  DateTime? _dateOfBirth;
  int? _waitingTime;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final patient = AppScope.read(context).patient;

    _nameController = TextEditingController(text: patient?.fullName ?? '');

    _emailController = TextEditingController(text: patient?.email ?? '');


    _dateOfBirth = patient?.dateOfBirth;

    _dobController = TextEditingController(
      text: _dateOfBirth == null ? '' : Fmt.date(_dateOfBirth!),
    );

    _waitingTime = patient?.waitingTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 65, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = Fmt.date(picked);
      });
    }
  }

  Future<void> _pickWaitingTime() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select waiting time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('30 seconds'),
                onTap: () {
                  Navigator.pop(context, 30);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('60 seconds'),
                onTap: () {
                  Navigator.pop(context, 60);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('90 seconds'),
                onTap: () {
                  Navigator.pop(context, 90);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('120 seconds'),
                onTap: () {
                  Navigator.pop(context, 120);
                },
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _waitingTime = selected;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final app = AppScope.read(context);
    final current = app.patient;

    if (current == null) return;

    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {

      final updated = Patient(
        id: current.id,
        fullName: _nameController.text.trim(),
        // The email is fixed at registration; never take it from the form.
        email: current.email,
        dateOfBirth: _dateOfBirth,
        waitingTime: _waitingTime,
      );

      await app.updateProfile(updated);

      if (_waitingTime != null) {
        await app.updateEscalation(_waitingTime!);
      }

      if (!mounted) return;

      if (widget.isSetup) {
        navigator.pushNamedAndRemoveUntil(Routes.home, (route) => false);
      } else {
        navigator.pop();

        messenger.showAppMessage(
          'Profile updated successfully',
          tone: ChipTone.success,
        );
      }
    } catch (_) {
      messenger.showAppMessage(
        'Could not save your profile. Please try again.',
        tone: ChipTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: widget.isSetup ? 'Set up your profile' : 'Edit profile',
      showBack: !widget.isSetup,
      bottom: widget.isSetup
          ? PrimaryButton(
              label: 'Save and Continue',
              loading: _saving,
              onPressed: _save,
            )
          : Row(
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
                    onPressed: _save,
                  ),
                ),
              ],
            ),
      children: [
        if (widget.isSetup) ...[
          Text('Welcome to ReStep!', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Please check your details. You can change them at any time '
            'from your profile.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
        ],
        Center(
          child: UserAvatar(
            initials: Patient(
              id: '',
              fullName: _nameController.text,
              email: '',
            ).initials,
            size: 88,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Full name',
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => Validators.required(v, 'Full name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Email',
                controller: _emailController,
                readOnly: true,
                prefixIcon: Icons.mail_outline_rounded,
                suffixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Email address cannot be changed.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Date of birth (optional)',
                hint: 'Select a date',
                controller: _dobController,
                readOnly: true,
                onTap: _pickDate,
                prefixIcon: Icons.cake_outlined,
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Waiting Time',
                hint: _waitingTime == null
                    ? 'Select waiting time'
                    : '${_waitingTime!} seconds',
                readOnly: true,
                onTap: _pickWaitingTime,
                prefixIcon: Icons.timer_outlined,
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                ),
                validator: (_) {
                  if (_waitingTime == null) {
                    return 'Waiting Time is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'During a freeze, ReStep waits this long for your response before alerting your emergency contact. You can change it anytime.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
