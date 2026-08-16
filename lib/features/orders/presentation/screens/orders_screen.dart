import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/locale/app_locale.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gp_states.dart';
import '../../../../domain/entities/order.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderFilter _filter = OrderFilter.all;
  List<CustomerOrder> _orders = const [];
  bool _loading = true;
  String? _error;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<CustomerOrder> get _visible {
    return _orders.where((o) {
      return switch (_filter) {
        OrderFilter.all => o.status != OrderStatus.draft,
        OrderFilter.completed => o.status == OrderStatus.delivered,
        OrderFilter.cancelled => o.status == OrderStatus.cancelled,
        OrderFilter.ongoing =>
          o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.draft,
      };
    }).toList();
  }

  Future<void> _open(CustomerOrder order) async {
    if (order.isBlockingNewBooking) {
      context.push(order.resumeRoute);
      return;
    }
    final cancelled = await context.push<bool>(
      RoutePaths.orderDetails,
      extra: order,
    );
    if (cancelled == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                s.orders,
                style: AppTypography.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: s.all,
                    selected: _filter == OrderFilter.all,
                    onTap: () => setState(() => _filter = OrderFilter.all),
                  ),
                  _FilterChip(
                    label: s.ongoing,
                    selected: _filter == OrderFilter.ongoing,
                    onTap: () => setState(() => _filter = OrderFilter.ongoing),
                  ),
                  _FilterChip(
                    label: s.completed,
                    selected: _filter == OrderFilter.completed,
                    onTap: () => setState(() => _filter = OrderFilter.completed),
                  ),
                  _FilterChip(
                    label: s.cancelled,
                    selected: _filter == OrderFilter.cancelled,
                    onTap: () => setState(() => _filter = OrderFilter.cancelled),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const GpLoadingState()
                  : _error != null
                      ? GpErrorState(message: _error!, onRetry: _load)
                      : _visible.isEmpty
                          ? GpEmptyState(
                              title: s.noOrders,
                              subtitle: s.noOrdersSub,
                              icon: Icons.inventory_2_outlined,
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  return _OrderCard(
                                    order: _visible[i],
                                    trackLabel: s.trackLive,
                                    onTap: () => _open(_visible[i]),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.brandNavy : Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AppColors.brandNavy : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.trackLabel,
    required this.onTap,
  });

  final CustomerOrder order;
  final String trackLabel;
  final VoidCallback onTap;

  Color get _statusColor => switch (order.status) {
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.error,
        OrderStatus.searching => AppColors.warning,
        _ => AppColors.primary,
      };

  Color get _statusBg => switch (order.status) {
        OrderStatus.delivered => AppColors.successLight,
        OrderStatus.cancelled => AppColors.errorLight,
        OrderStatus.searching => const Color(0xFFFEF3C7),
        _ => AppColors.primaryLight,
      };

  IconData get _parcelIcon => switch (order.parcelType) {
        ParcelType.documents => Icons.description_outlined,
        ParcelType.electronics => Icons.devices_other_outlined,
        ParcelType.clothes => Icons.checkroom_outlined,
        ParcelType.food => Icons.inventory_2_outlined,
        ParcelType.others => Icons.inventory_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_parcelIcon, size: 18, color: AppColors.brandNavy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderCode,
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${order.parcelTypeLabel} · ${Formatters.shortDate(order.createdAt)}',
                          style: AppTypography.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: AppTypography.textTheme.labelSmall?.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MiniRoute(
                pickup: order.pickup.address,
                drop: order.drop.address,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    Formatters.currency(order.fare),
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandNavy,
                    ),
                  ),
                  const Spacer(),
                  if (order.isBlockingNewBooking)
                    Text(
                      trackLabel,
                      style: AppTypography.textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRoute extends StatelessWidget {
  const _MiniRoute({required this.pickup, required this.drop});

  final String pickup;
  final String drop;

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
                color: AppColors.pickup,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 22,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: AppColors.border,
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.drop,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                drop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
