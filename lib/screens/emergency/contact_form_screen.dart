
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    for (final contact in app.contacts) {
      if (contact.id == widget.contactId) {
        _existing = contact;
      }
    }

    final existing = _existing;

    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone;
      _designated = existing.isDesignated;
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
        phone: Validators.normalizeSaudiMobile(
          _phoneController.text,
        )!,
        isDesignated: _designated,
      ),
    );

    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pop();

    messenger.showAppMessage(
      'Emergency contact saved successfully.',
      tone: ChipTone.success,
    );
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final contact = _existing!;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // A designated contact cannot be deleted while other contacts exist.
    if (contact.isDesignated && app.contacts.length > 1) {
      messenger.showAppMessage(
        'You cannot delete this contact because they are designated as your emergency contact.',
      );
      return;
    }

    final isLastContact = app.contacts.length == 1;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove contact?',
      message: isLastContact
          ? 'This is your only emergency contact. Removing it will disable Emergency Contacts.\n Do you want to continue?'
          : '${contact.name} will no longer be alerted if you need help.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );

    if (!confirmed) return;

    app.removeContact(contact.id);

    // Disable Emergency Contacts when the last contact is deleted.
    if (isLastContact) {
      await app.setEmergencyContactsEnabled(false);
    }

    if (!mounted) return;

    navigator.pop();

    messenger.showAppMessage(
      'Contact removed successfully.',
      tone: ChipTone.success,
    );
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
            child: PrimaryButton(
              label: 'Save',
              onPressed: _save,
            ),
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
                validator: (value) => Validators.required(
                  value,
                  'Name',
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Phone number',
                hint: '+966 5X XXX XXXX',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.phone_outlined,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9+\s\-()]'),
                  ),
                ],
                validator: Validators.saudiMobile,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Saudi mobile number: +966 followed by 9 digits starting with 5. A number starting with 05 is also accepted.',
                  style: theme.textTheme.bodySmall,
                ),
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
                          ? 'This contact receives the alert. To change it, designate another contact.'
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
                      : (value) => setState(
                        () => _designated = value,
                  ),
                  thumbColor: const WidgetStatePropertyAll(
                    Colors.white,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                        (states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.navy;
                      }
                      return AppColors.muted;
                    },
                  ),
                  trackOutlineColor:
                  const WidgetStatePropertyAll(
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
