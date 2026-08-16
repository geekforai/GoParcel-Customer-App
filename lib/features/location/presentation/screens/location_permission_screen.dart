import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/gp_outline_button.dart';
import '../../../../core/widgets/gp_primary_button.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _grantAndGo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await LocationService().ensurePermission();
    await ref.read(customerRepositoryProvider).setLocationGranted(true);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() => _error = 'Location permission denied. You can still book manually.');
    }
    context.go(RoutePaths.home);
  }

  Future<void> _skip() async {
    await ref.read(customerRepositoryProvider).setLocationGranted(true);
    if (!mounted) return;
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Enable Location',
                style: AppTypography.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We need your location to place the pickup pin accurately — just like Porter.',
                style: AppTypography.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              GpPrimaryButton(
                label: 'Use Current Location',
                isLoading: _loading,
                onPressed: _grantAndGo,
              ),
              const SizedBox(height: 12),
              GpOutlineButton(
                label: 'Continue without GPS',
                onPressed: _loading ? null : _skip,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
