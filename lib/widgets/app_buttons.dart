import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';

/// Large filled button (min height 56). Use [DestructiveButton] (or
/// [backgroundColor] = [AppColors.danger]) for destructive actions.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.backgroundColor = AppColors.navy,
    this.foregroundColor = Colors.white,
    this.minHeight = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final Color backgroundColor;
  final Color foregroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final Widget content = loading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: foregroundColor,
              backgroundColor: Colors.transparent,
            ),
          )
        : _ButtonLabel(label: label, icon: icon, iconSize: 24);

    return PressScale(
      enabled: onPressed != null && !loading,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: Semantics(
          label: loading ? '$label, loading' : null,
          child: FilledButton(
            // Keeps the enabled color while loading but ignores taps.
            onPressed: loading ? () {} : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.muted,
              minimumSize: Size(64, minHeight),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.fast),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Red filled button for irreversible actions (delete, remove...).
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expand: expand,
      backgroundColor: AppColors.danger,
    );
  }
}

/// Large outlined button. [color] changes the outline/text color (e.g. red).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.color = AppColors.navy,
    this.minHeight = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            minimumSize: Size(64, minHeight),
            side: BorderSide(
              color: onPressed == null ? AppColors.border : color,
              width: 1.5,
            ),
          ),
          child: _ButtonLabel(label: label, icon: icon, iconSize: 22),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon, required this.iconSize});

  final String label;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 2)),
      ],
    );
  }
}

/// Gentle iOS-style "press down" feedback: the child shrinks slightly while
/// a finger is on it. Disabled when animations are reduced.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
