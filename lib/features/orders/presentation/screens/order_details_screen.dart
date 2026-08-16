import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/locale/app_locale.dart';
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

  Color get _statusColor => switch (_order.status) {
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.error,
        OrderStatus.searching => AppColors.warning,
        _ => AppColors.primary,
      };

  Future<void> _cancel() async {
    if (!_order.canCancelTrip) return;
    final s = ref.read(l10nProvider);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.cancelOrder,
              style: AppTypography.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(s.cancelUntilPickup, style: AppTypography.textTheme.bodyMedium),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.keepOrder),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: Text(s.cancelOrder),
            ),
          ],
        ),
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

    if (ok && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final order = _order;
    final showOtp = order.driver != null &&
        order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.delivered;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
        title: Text(s.orderDetails),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderCode,
                        style: AppTypography.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.bookedOn} ${Formatters.dateTime(order.createdAt)}',
                        style: AppTypography.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  order.statusLabel,
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tripRoute,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _RouteRow(
                  color: AppColors.pickup,
                  title: s.pickup,
                  address: order.pickup.address,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
                _RouteRow(
                  color: AppColors.drop,
                  title: s.drop,
                  address: order.drop.address,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                _KV(s.shipment, order.parcelTypeLabel),
                _KV(s.weight, order.weightLabel),
                _KV(s.farePaid, Formatters.currency(order.fare), emphasize: true),
                if (order.tip > 0) _KV(s.tipOptional, Formatters.currency(order.tip)),
                if (order.instructions.isNotEmpty)
                  _KV(s.instructions, order.instructions, last: true),
              ],
            ),
          ),
          if (order.driver != null) ...[
            const SizedBox(height: 12),
            _Card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      order.driver!.displayName[0],
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.partner,
                          style: AppTypography.textTheme.bodySmall,
                        ),
                        Text(
                          '${order.driver!.displayName} · ${order.driver!.vehicleLabel}',
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          order.driver!.displayPhone,
                          style: AppTypography.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showOtp &&
              (order.pickupOtp.isNotEmpty || order.deliveryOtp.isNotEmpty)) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.shareOtpHint,
                    style: AppTypography.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (order.pickupOtp.isNotEmpty)
                        Expanded(
                          child: _OtpTile(label: s.pickupOtp, code: order.pickupOtp),
                        ),
                      if (order.pickupOtp.isNotEmpty &&
                          order.deliveryOtp.isNotEmpty)
                        const SizedBox(width: 10),
                      if (order.deliveryOtp.isNotEmpty)
                        Expanded(
                          child: _OtpTile(
                            label: s.deliveryOtp,
                            code: order.deliveryOtp,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.timeline,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (order.timeline.isEmpty)
                  Text(s.noTimeline, style: AppTypography.textTheme.bodyMedium)
                else
                  ...order.timeline.asMap().entries.map((e) {
                    final isLast = e.key == order.timeline.length - 1;
                    return _TimelineRow(event: e.value, isLast: isLast);
                  }),
              ],
            ),
          ),
          if (order.canCancelTrip) ...[
            const SizedBox(height: 20),
            SizedBox(
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
                    : Text(s.cancelOrder),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.color,
    required this.title,
    required this.address,
  });

  final Color color;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                address,
                style: AppTypography.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value, {this.emphasize = false, this.last = false});

  final String label;
  final String value;
  final bool emphasize;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AppTypography.textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasize
                      ? AppTypography.textTheme.titleLarge
                      : AppTypography.textTheme.titleMedium)
                  ?.copyWith(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize ? AppColors.brandNavy : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpTile extends StatelessWidget {
  const _OtpTile({required this.label, required this.code});

  final String label;
  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('$label copied'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              code,
              style: AppTypography.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final OrderTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: AppColors.primaryLight,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: AppTypography.textTheme.titleMedium),
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
  }
}
