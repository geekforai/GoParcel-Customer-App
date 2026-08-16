import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

class DeliveryCompletedScreen extends ConsumerStatefulWidget {
  const DeliveryCompletedScreen({super.key});

  @override
  ConsumerState<DeliveryCompletedScreen> createState() =>
      _DeliveryCompletedScreenState();
}

class _DeliveryCompletedScreenState
    extends ConsumerState<DeliveryCompletedScreen>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _bookAnother() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate your driver')),
      );
      return;
    }
    await ref.read(bookingProvider.notifier).rate(_rating);
    final order = ref.read(bookingProvider).order;
    if (order?.electric == true) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt('gp_ev_trips', (prefs.getInt('gp_ev_trips') ?? 0) + 1);
    }
    await ref.read(bookingProvider.notifier).clearActive();
    if (mounted) context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingProvider).order;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFF6FF),
              Color(0xFFFFFFFF),
              Color(0xFFF0FDF4),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _pop,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 56,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Delivered!',
                  style: AppTypography.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  order == null
                      ? 'Your parcel arrived safely.'
                      : '${order.orderCode} · ${Formatters.currency(order.fare)}',
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (order != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: BookingRouteStrip(
                      pickup: order.pickup.address,
                      drop: order.drop.address,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'How was your experience?',
                  style: AppTypography.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final selected = star <= _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = star),
                      child: AnimatedScale(
                        scale: selected ? 1.08 : 1,
                        duration: const Duration(milliseconds: 160),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            selected
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 40,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(flex: 3),
                BookingPrimaryButton(
                  label: 'Book another',
                  onPressed: _bookAnother,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
