import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

enum GpBrandLogoVariant {
  /// Icon mark only (app bars, small chrome).
  icon,

  /// Icon + GoParcel wordmark in a horizontal row.
  compact,

  /// Full stacked logo with tagline.
  full,
}

class GpBrandLogo extends StatelessWidget {
  const GpBrandLogo({
    super.key,
    this.height = 36,
    this.variant = GpBrandLogoVariant.compact,
  });

  /// Visual height of the logo / icon.
  final double height;

  final GpBrandLogoVariant variant;

  static const String iconAsset = 'assets/icons/app_icon.png';
  static const String fullLogoAsset = 'assets/images/logo_full.png';

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      GpBrandLogoVariant.icon => Image.asset(
          iconAsset,
          width: height,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      GpBrandLogoVariant.compact => _CompactLogo(size: height),
      GpBrandLogoVariant.full => Image.asset(
          fullLogoAsset,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
    };
  }
}

class _CompactLogo extends StatelessWidget {
  const _CompactLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 1.15;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          GpBrandLogo.iconAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(width: size * 0.22),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Go',
                style: AppTypography.brandLogo.copyWith(
                  fontSize: size,
                  color: AppColors.brandNavy,
                ),
              ),
              TextSpan(
                text: 'Parcel',
                style: AppTypography.brandLogoAccent.copyWith(
                  fontSize: size,
                  color: AppColors.brandGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
