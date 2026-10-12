import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Consistent logo heights used throughout the app.
/// The logo image has a 3:1 aspect ratio.
enum LogoSize {
  small(30),
  medium(44),
  large(64),
  hero(92);

  const LogoSize(this.height);
  final double height;
}

/// The ReStep logo. Always loads assets/images/restep_logo.png.
/// If the file is missing, a plain labelled placeholder is shown instead
/// (no replacement artwork is invented).
class ReStepLogo extends StatelessWidget {
  const ReStepLogo({super.key, this.size = LogoSize.medium});

  final LogoSize size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      height: size.height,
      fit: BoxFit.contain,
      semanticLabel: 'ReStep logo',
      errorBuilder: (context, error, stackTrace) =>
          _LogoPlaceholder(height: size.height),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: height * 3,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.skyTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sky),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            'Add logo: assets/images/restep_logo.png',
            style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ),
      ),
    );
  }
}
