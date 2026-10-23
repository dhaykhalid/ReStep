import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// Development tool: a live line chart for one sensor (X, Y and Z).
/// It draws the readings it is given, oldest on the left and newest
/// on the right. Drawn with CustomPainter, so no chart package is needed.
class LiveChart extends StatelessWidget {
  const LiveChart({
    super.key,
    required this.title,
    required this.x,
    required this.y,
    required this.z,
  });

  final String title;
  final List<double> x;
  final List<double> y;
  final List<double> z;

  // One color per axis
  static const Color xColor = Colors.red;
  static const Color yColor = Colors.green;
  static const Color zColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _Legend(color: xColor, label: 'X'),
              SizedBox(width: 16),
              _Legend(color: yColor, label: 'Y'),
              SizedBox(width: 16),
              _Legend(color: zColor, label: 'Z'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _ChartPainter(x: x, y: y, z: z),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small colored dot with the axis name.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
      ],
    );
  }
}

/// Draws the three lines on a canvas.
class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.x, required this.y, required this.z});

  final List<double> x;
  final List<double> y;
  final List<double> z;

  @override
  void paint(Canvas canvas, Size size) {
    // Frame around the chart
    final frame = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, frame);

    // We need at least 2 readings to draw a line
    if (x.length < 2) return;

    // 1. Find the smallest and largest value on screen
    final all = [...x, ...y, ...z];
    var minV = all.reduce((a, b) => a < b ? a : b);
    var maxV = all.reduce((a, b) => a > b ? a : b);

    // Keep a minimum range, so a still sensor does not zoom into noise
    if (maxV - minV < 2) {
      final middle = (maxV + minV) / 2;
      minV = middle - 1;
      maxV = middle + 1;
    }

    // Small empty space at the top and bottom
    final margin = (maxV - minV) * 0.1;
    minV -= margin;
    maxV += margin;

    // 2. Convert a value to its height on the canvas
    double toY(double v) =>
        size.height - (v - minV) / (maxV - minV) * size.height;

    // 3. Grey line at zero (if zero is inside the range)
    if (minV < 0 && maxV > 0) {
      final zeroLine = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, toY(0)),
        Offset(size.width, toY(0)),
        zeroLine,
      );
    }

    // 4. The three axes
    _drawLine(canvas, size, x, LiveChart.xColor, toY);
    _drawLine(canvas, size, y, LiveChart.yColor, toY);
    _drawLine(canvas, size, z, LiveChart.zColor, toY);

    // 5. Largest and smallest value as labels on the left
    _drawLabel(canvas, maxV.toStringAsFixed(1), const Offset(4, 2));
    _drawLabel(canvas, minV.toStringAsFixed(1), Offset(4, size.height - 16));
  }

  void _drawLine(
      Canvas canvas,
      Size size,
      List<double> values,
      Color color,
      double Function(double) toY,
      ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      // Reading number i goes from the left edge (0) to the right edge
      final px = i / (values.length - 1) * size.width;
      final py = toY(values[i]);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, String text, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  // New readings arrive all the time, so always redraw.
  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}