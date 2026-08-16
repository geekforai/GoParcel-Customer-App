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
import '../../../../domain/entities/customer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  CustomerProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(customerRepositoryProvider).getProfile();
    if (!mounted) return;
    result.when(
      success: (p) => setState(() {
        _profile = p;
        _loading = false;
      }),
      failure: (m) => setState(() {
        _error = m;
        _loading = false;
      }),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: GpLoadingState());
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        body: GpErrorState(
          message: _error ?? 'Unable to load profile',
          onRetry: _load,
        ),
      );
    }

    final profile = _profile!;

    final menu = [
      (
        Icons.home_work_outlined,
        'Saved Addresses',
        RoutePaths.savedAddresses,
        null
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Wallet',
        RoutePaths.wallet,
        Formatters.currency(profile.walletBalance)
      ),
      (
        Icons.credit_card_outlined,
        'Payment Methods',
        RoutePaths.paymentMethods,
        null
      ),
      (Icons.support_agent_outlined, 'Support', RoutePaths.support, null),
      (Icons.settings_outlined, 'Settings', RoutePaths.settings, null),
      (Icons.info_outline, 'About', RoutePaths.about, null),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : 'G',
                    style: AppTypography.textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(profile.name, style: AppTypography.textTheme.headlineSmall),
                Text(
                  '+91 ${profile.phone}',
                  style: AppTypography.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _GstAndCo2(phone: profile.phone),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ...menu.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: ListTile(
                leading: Icon(item.$1, color: AppColors.primary),
                title: Text(item.$2, style: AppTypography.textTheme.titleMedium),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.$4 != null)
                      Text(
                        item.$4!,
                        style: AppTypography.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary),
                  ],
                ),
                onTap: () => context.push(item.$3),
              ),
            );
          }),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text(
              'Logout',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

class _GstAndCo2 extends ConsumerStatefulWidget {
  const _GstAndCo2({required this.phone});
  final String phone;

  @override
  ConsumerState<_GstAndCo2> createState() => _GstAndCo2State();
}

class _GstAndCo2State extends ConsumerState<_GstAndCo2> {
  late final TextEditingController _gst;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _gst = TextEditingController(text: prefs.getString('gp_customer_gstin') ?? '');
  }

  @override
  void dispose() {
    _gst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final evTrips = prefs.getInt('gp_ev_trips') ?? 0;
    final co2 = (evTrips * 0.21).toStringAsFixed(2);
    return Column(
      children: [
        TextField(
          controller: _gst,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'GSTIN (optional)',
            isDense: true,
          ),
          onChanged: (v) => prefs.setString('gp_customer_gstin', v.trim()),
        ),
        const SizedBox(height: 8),
        Text(
          'CO₂ saved from EV trips: $co2 kg',
          style: AppTypography.textTheme.bodySmall,
        ),
      ],
    );
  }
}
