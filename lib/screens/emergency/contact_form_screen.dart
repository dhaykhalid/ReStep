import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/emergency.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Add or edit an emergency contact. Pass [contactId] to edit.
class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key, this.contactId});

  final String? contactId;

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  EmergencyContact? _existing;
  bool _designated = false;
  bool _locked = false;

  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    for (final c in app.contacts) {
      if (c.id == widget.contactId) _existing = c;
    }
    final existing = _existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone;
      _designated = existing.isDesignated;
      // The current designated contact stays designated until another contact
      // is chosen.
      _locked = existing.isDesignated;
    } else if (app.contacts.isEmpty) {
      // The first contact is designated automatically.
      _designated = true;
      _locked = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    app.saveContact(
      EmergencyContact(
        id: _existing?.id ?? app.newContactId(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        isDesignated: _designated,
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showAppMessage('Emergency contact saved', tone: ChipTone.success);
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove contact?',
      message: '${_existing!.name} will no longer be alerted if you need help.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!confirmed) return;
    app.removeContact(_existing!.id);
    navigator.pop();
    messenger.showAppMessage('Contact removed', tone: ChipTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: _isEditing ? 'Edit contact' : 'Add contact',
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
                label: 'Name',
                hint: 'Contact name',
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Phone number',
                hint: '+966 5X XXX XXXX',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.phone_outlined,
                validator: Validators.phone,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Designated contact',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _locked
                          ? 'This contact receives the alert. To change it, '
                                'designate another contact.'
                          : 'Receives the alert if you do not respond.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.scale(
                scale: 1.15,
                child: Switch(
                  value: _designated,
                  onChanged: _locked
                      ? null
                      : (v) => setState(() => _designated = v),
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.navy;
                    }
                    return AppColors.muted;
                  }),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 28),
          SecondaryButton(
            label: 'Remove Contact',
            icon: Icons.person_remove_outlined,
            color: AppColors.danger,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
