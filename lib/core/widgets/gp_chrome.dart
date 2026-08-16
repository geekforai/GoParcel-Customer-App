import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shadows.dart';
import '../../app/theme/app_typography.dart';

class GpBottomNav extends StatelessWidget {
  const GpBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders'),
    (Icons.notifications_rounded, Icons.notifications_outlined, 'Alerts'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: AppShadows.bottomNav),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = currentIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.$1 : item.$2,
                          color: selected ? AppColors.primary : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            color: selected ? AppColors.primary : AppColors.textTertiary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class GpMapPlaceholder extends StatelessWidget {
  const GpMapPlaceholder({
    super.key,
    this.height = 160,
    this.showRoute = false,
  });

  final double height;
  final bool showRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        showRoute ? Icons.route_rounded : Icons.map_outlined,
        color: AppColors.primary.withValues(alpha: 0.45),
        size: 36,
      ),
    );
  }
}
