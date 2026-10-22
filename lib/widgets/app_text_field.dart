import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

/// Labelled text field with consistent styling, validation and an optional
/// show/hide control for passwords. Also used as a read-only "picker" field.
///
/// Validation feedback: no error is shown while the patient types into a
/// field for the first time. The field is checked when they leave it after
/// editing, or when the form is submitted; from then on it is re-checked on
/// every change, so an error disappears as soon as the input becomes valid.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.revalidateOn,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// Something else this field's [validator] reads (such as the password a
  /// "confirm password" field must match). Once the field has been checked,
  /// it is re-checked whenever this notifies.
  final Listenable? revalidateOn;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword;

  final _focusNode = FocusNode();

  /// The patient has typed into the field.
  bool _edited = false;

  /// The field has been checked at least once (on leaving it or on submit);
  /// from then on it validates on every change.
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.revalidateOn?.addListener(_onDependencyChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revalidateOn != widget.revalidateOn) {
      oldWidget.revalidateOn?.removeListener(_onDependencyChange);
      widget.revalidateOn?.addListener(_onDependencyChange);
    }
  }

  @override
  void dispose() {
    widget.revalidateOn?.removeListener(_onDependencyChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _edited && !_validated) {
      setState(() => _validated = true);
    }
  }

  void _onDependencyChange() {
    if (_validated) setState(() {});
  }

  String? _validate(String? value) {
    final validator = widget.validator;
    if (validator == null) return null;
    // A submit validates every field; keep each one live from then on.
    if (!_validated) setState(() => _validated = true);
    return validator(value);
  }

  OutlineInputBorder _border(Color color, [double width = 1.5]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          validator: widget.validator == null ? null : _validate,
          autovalidateMode: _validated
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          obscureText: _obscure,
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          onChanged: (value) {
            _edited = true;
            widget.onChanged?.call(value);
          },
          onFieldSubmitted: widget.onFieldSubmitted,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          style: theme.textTheme.bodyLarge,
          cursorColor: AppColors.navy,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, color: AppColors.navy),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    iconSize: 26,
                    color: AppColors.muted,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : widget.suffixIcon,
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.navy, 2),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, 2),
            errorMaxLines: 3,
            errorStyle: const TextStyle(
              fontSize: 14,
              height: 1.3,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
