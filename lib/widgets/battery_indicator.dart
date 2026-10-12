import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Battery icon + percentage. Turns red when the battery is low.
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, required this.percent});

  final int percent;

  IconData get _icon {
    if (percent > 85) return Icons.battery_full_rounded;
    if (percent > 65) return Icons.battery_6_bar_rounded;
    if (percent > 45) return Icons.battery_4_bar_rounded;
    if (percent > 25) return Icons.battery_3_bar_rounded;
    if (percent > 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final low = percent <= 20;
    final color = low ? AppColors.danger : AppColors.navy;
    return Semantics(
      label: 'Battery $percent percent',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: color, size: 24),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
