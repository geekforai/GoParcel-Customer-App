import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/debug/agent_log.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gp_states.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../booking/presentation/providers/booking_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CustomerProfile? _profile;
  List<SavedAddress> _addresses = const [];
  List<CustomerOrder> _orders = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // #region agent log
    final sw = Stopwatch()..start();
    agentLog(
      'customer_home',
      'load start',
      hypothesisId: 'G',
      runId: 'post-fix',
    );
    // #endregion

    // Instant local shell so UI never waits on dead backend.
    final sessionResult =
        await ref.read(authRepositoryProvider).getSession();
    AuthSession? session;
    sessionResult.when(success: (s) => session = s, failure: (_) {});
    if (session != null && session!.isAuthenticated && mounted) {
      setState(() {
        _profile = CustomerProfile(
          id: session!.userId,
          name: session!.fullName.isEmpty ? 'Customer' : session!.fullName,
          phone: session!.phone,
          walletBalance: 0,
        );
        _addresses = const [];
        _orders = const [];
        _error = null;
        _loading = false;
      });
      // #region agent log
      agentLog(
        'customer_home',
        'instant local shell',
        hypothesisId: 'G',
        runId: 'post-fix',
        data: {'ms': sw.elapsedMilliseconds},
      );
      // #endregion
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final profileFuture = ref.read(customerRepositoryProvider).getProfile();
    final addressFuture =
        ref.read(customerRepositoryProvider).getSavedAddresses();
    final ordersFuture = ref.read(orderRepositoryProvider).getOrders();
    final profileResult = await profileFuture;
    final addressResult = await addressFuture;
    final ordersResult = await ordersFuture;

    // #region agent log
    agentLog(
      'customer_home',
      'api refresh done',
      hypothesisId: 'G',
      runId: 'post-fix',
      data: {'ms': sw.elapsedMilliseconds},
    );
    // #endregion

    if (!mounted) return;

    String? error;
    CustomerProfile? profile;
    List<SavedAddress> addresses = const [];
    List<CustomerOrder> orders = const [];

    profileResult.when(
      success: (p) => profile = p,
      failure: (m) => error = m,
    );
    addressResult.when(
      success: (a) => addresses = a,
      failure: (_) {},
    );
    ordersResult.when(
      success: (o) => orders = o,
      failure: (_) {},
    );

    // #region agent log
    agentLog(
      'customer_home',
      'load finish',
      hypothesisId: 'G',
      runId: 'post-fix',
      data: {
        'ms': sw.elapsedMilliseconds,
        'hasProfile': profile != null || _profile != null,
        'hasError': error != null && profile == null && _profile == null,
      },
    );
    // #endregion

    setState(() {
      _profile = profile ?? _profile;
      _addresses = addresses;
      _orders = orders;
      _error = (_profile == null && profile == null) ? error : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: GpLoadingState());
    }
    if (_error != null && _profile == null) {
      return Scaffold(
        body: GpErrorState(message: _error!, onRetry: _load),
      );
    }

    final profile = _profile!;
    final recent = _orders.where((o) => o.status == OrderStatus.delivered).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Formatters.greeting()},',
                          style: AppTypography.textTheme.bodyMedium,
                        ),
                        Text(
                          profile.name,
                          style: AppTypography.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : 'G',
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sector 62, Noida',
                        style: AppTypography.textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Saved addresses', style: AppTypography.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (_addresses.isEmpty)
                const GpEmptyState(
                  title: 'No saved addresses',
                  subtitle: 'Add Home or Work to book faster',
                  icon: Icons.home_outlined,
                )
              else
                ..._addresses.map((a) => _AddressRow(address: a)),
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  // Always start the booking flow. createDraft clears stale
                  // local/server blockers so "ghost" trips cannot trap the user.
                  context.push(RoutePaths.bookingLocations);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book a parcel',
                              style: AppTypography.textTheme.titleLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Same-city delivery in minutes',
                              style: AppTypography.textTheme.bodyMedium
                                  ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
              if (ref.watch(bookingProvider).order?.isBlockingNewBooking ??
                  false) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    final active = ref.read(bookingProvider).order;
                    if (active == null) return;
                    context.push(active.resumeRoute);
                  },
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: const Text('Continue active trip'),
                ),
              ],
              const SizedBox(height: 24),
              Text('Recent orders', style: AppTypography.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                const GpEmptyState(
                  title: 'No recent orders',
                  subtitle: 'Your deliveries will show up here',
                )
              else
                _RecentOrderCard(order: recent.first),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final SavedAddress address;

  IconData get _icon => switch (address.label.toLowerCase()) {
        'home' => Icons.home_rounded,
        'work' => Icons.work_rounded,
        _ => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label, style: AppTypography.textTheme.titleMedium),
                Text(address.address, style: AppTypography.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.orderDetails, extra: order),
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
                Text(order.orderCode, style: AppTypography.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: AppTypography.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${order.pickup.address} → ${order.drop.address}',
              style: AppTypography.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.currency(order.fare),
              style: AppTypography.textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
