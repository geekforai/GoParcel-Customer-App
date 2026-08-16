import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gp_states.dart';
import '../../../../domain/entities/order.dart';
import '../../../booking/presentation/providers/booking_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<CustomerOrder> _orders = const [];
  bool _loading = true;
  String? _error;

  static const _filters = [
    OrderFilter.all,
    OrderFilter.completed,
    OrderFilter.ongoing,
    OrderFilter.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(orderRepositoryProvider).getOrders();
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _orders = list;
        _loading = false;
      }),
      failure: (m) => setState(() {
        _error = m;
        _loading = false;
      }),
    );
  }

  List<CustomerOrder> _filtered(OrderFilter filter) {
    return _orders.where((o) {
      return switch (filter) {
        OrderFilter.all => true,
        OrderFilter.completed => o.status == OrderStatus.delivered,
        OrderFilter.cancelled => o.status == OrderStatus.cancelled,
        OrderFilter.ongoing =>
          o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.draft,
      };
    }).toList();
  }

  Future<void> _cancelFromList(CustomerOrder order) async {
    if (!order.canCancelTrip) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text(
          'Cancel ${order.orderCode}? You can cancel until the parcel is picked up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
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

    final result =
        await ref.read(orderRepositoryProvider).cancelOrder(order.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        final active = ref.read(bookingProvider).order;
        if (active != null &&
            (active.id == order.id || active.orderCode == order.orderCode)) {
          ref.read(bookingProvider.notifier).clearActive();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Order cancelled'),
          ),
        );
        _load();
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message),
          ),
        );
      },
    );
  }

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.error,
        _ => AppColors.primary,
      };

  Color _statusBg(OrderStatus status) => switch (status) {
        OrderStatus.delivered => AppColors.successLight,
        OrderStatus.cancelled => AppColors.errorLight,
        _ => AppColors.primaryLight,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _loading
          ? const GpLoadingState()
          : _error != null
              ? GpErrorState(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: _filters.map((filter) {
                    final list = _filtered(filter);
                    if (list.isEmpty) {
                      return const GpEmptyState(
                        title: 'No orders yet',
                        subtitle: 'Book a parcel to see it here',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final order = list[i];
                          return InkWell(
                            onTap: () async {
                              final cancelled = await context.push<bool>(
                                RoutePaths.orderDetails,
                                extra: order,
                              );
                              if (cancelled == true && mounted) _load();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppShadows.card,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        order.orderCode,
                                        style:
                                            AppTypography.textTheme.titleMedium,
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusBg(order.status),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          order.statusLabel,
                                          style: AppTypography
                                              .textTheme.labelMedium
                                              ?.copyWith(
                                            color: _statusColor(order.status),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${order.pickup.address} → ${order.drop.address}',
                                    style: AppTypography.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        Formatters.currency(order.fare),
                                        style: AppTypography
                                            .textTheme.titleMedium
                                            ?.copyWith(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        Formatters.shortDate(order.createdAt),
                                        style:
                                            AppTypography.textTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                  if (order.canCancelTrip) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _cancelFromList(order),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
