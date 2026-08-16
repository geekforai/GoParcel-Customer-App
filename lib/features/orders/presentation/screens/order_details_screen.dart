import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/order.dart';
import '../../../booking/presentation/providers/booking_provider.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.order});

  final CustomerOrder order;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  late CustomerOrder _order;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _cancel() async {
    if (!_order.canCancelTrip) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'You can cancel until the parcel is picked up. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final result =
        await ref.read(orderRepositoryProvider).cancelOrder(_order.id);
    if (!mounted) return;

    final ok = result.when(
      success: (updated) {
        setState(() {
          _order = updated;
          _cancelling = false;
        });
        // Clear live booking if this was the active trip.
        final active = ref.read(bookingProvider).order;
        if (active != null &&
            (active.id == _order.id ||
                active.orderCode == _order.orderCode)) {
          ref.read(bookingProvider.notifier).clearActive();
        }
        return true;
      },
      failure: (message) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message),
          ),
        );
        return false;
      },
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Order cancelled'),
        ),
      );
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderCode),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InfoRow(label: 'Status', value: order.statusLabel),
          _InfoRow(label: 'Fare', value: Formatters.currency(order.fare)),
          _InfoRow(label: 'Parcel', value: order.parcelTypeLabel),
          _InfoRow(label: 'Weight', value: order.weightLabel),
          _InfoRow(label: 'Pickup', value: order.pickup.address),
          _InfoRow(label: 'Delivery', value: order.drop.address),
          if (order.instructions.isNotEmpty)
            _InfoRow(label: 'Instructions', value: order.instructions),
          if (order.driver != null) ...[
            _InfoRow(label: 'Driver', value: order.driver!.displayName),
            if (order.driver!.phone.isNotEmpty)
              _InfoRow(label: 'Phone', value: order.driver!.displayPhone),
          ],
          if (order.pickupOtp.isNotEmpty)
            _InfoRow(label: 'Pickup OTP', value: order.pickupOtp),
          if (order.deliveryOtp.isNotEmpty)
            _InfoRow(label: 'Delivery OTP', value: order.deliveryOtp),
          const SizedBox(height: 24),
          Text('Timeline', style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (order.timeline.isEmpty)
            Text(
              'No timeline events yet',
              style: AppTypography.textTheme.bodyMedium,
            )
          else
            ...order.timeline.asMap().entries.map((e) {
              final isLast = e.key == order.timeline.length - 1;
              final event = e.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: AppColors.primaryLight,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: AppTypography.textTheme.titleMedium,
                          ),
                          Text(
                            Formatters.dateTime(event.at),
                            style: AppTypography.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          if (order.canCancelTrip) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _cancelling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _cancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel order'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can cancel until the parcel is picked up.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTypography.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: AppTypography.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
