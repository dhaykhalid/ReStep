import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class BarDatum {
  const BarDatum(this.label, this.value);
  final String label;
  final int value;
}

/// Simple, readable bar chart (one clear chart, as requested in the interviews).
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.data,
    this.chartHeight = 140,
  });

  final List<BarDatum> data;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    var maxValue = 1;
    for (final d in data) {
      if (d.value > maxValue) maxValue = d.value;
    }
    const valueLabelSpace = 24.0;
    final barArea = chartHeight - valueLabelSpace;

    return Semantics(
      label: 'Bar chart. ' +
          data.map((d) => '${d.label}: ${d.value}').join(', '),
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < data.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              data[i].value > 0 ? '${data[i].value}' : '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: data[i].value == 0
                                  ? 4
                                  : (barArea - 4) * data[i].value / maxValue,
                              decoration: BoxDecoration(
                                color: i == data.length - 1
                                    ? AppColors.navy
                                    : AppColors.sky,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final d in data)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
