import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gp_google_map.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

class DriverAssignedScreen extends ConsumerStatefulWidget {
  const DriverAssignedScreen({super.key});

  @override
  ConsumerState<DriverAssignedScreen> createState() =>
      _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends ConsumerState<DriverAssignedScreen>
    with SingleTickerProviderStateMixin {
  final _mapKey = GlobalKey<GpGoogleMapState>();
  final _sheetKey = GlobalKey();
  final _directions = DirectionsService();
  bool _cancelling = false;
  double _sheetHeight = 320;
  List<LatLng> _route = const [];
  String? _routeKey;
  Timer? _poll;
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(bookingProvider.notifier).refreshActiveTrip();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingProvider.notifier).refreshActiveTrip();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _fadeIn.dispose();
    super.dispose();
  }

  void _measureSheet() {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final h = box.size.height;
    if ((h - _sheetHeight).abs() > 2) setState(() => _sheetHeight = h);
  }

  Future<void> _ensureRoute(LatLng pickup, LatLng drop) async {
    final key =
        '${pickup.latitude},${pickup.longitude}->${drop.latitude},${drop.longitude}';
    if (_routeKey == key) return;
    _routeKey = key;
    final pts = await _directions.drivingRoute(
      origin: pickup,
      destination: drop,
    );
    if (!mounted || _routeKey != key) return;
    setState(() => _route = pts);
    await _mapKey.currentState?.fitBounds(pts.length >= 2 ? pts : [pickup, drop]);
  }

  Future<void> _startTracking() async {
    // Stay on pre-pickup statuses so customer can still cancel until OTP pickup.
    context.go(RoutePaths.bookingTracking);
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: const Text(
          'Driver is already assigned. You can cancel until the parcel is picked up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep trip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    final ok = await ref.read(bookingProvider.notifier).cancel();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      context.go(RoutePaths.home);
      return;
    }
    final err = ref.read(bookingProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(err ?? 'Could not cancel trip'),
      ),
    );
  }

  Future<void> _callDriver(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingProvider).order;
    final driver = order?.driver;
    final pickup = LatLng(
      order?.pickup.point.lat ?? 28.62,
      order?.pickup.point.lng ?? 77.36,
    );
    final drop = LatLng(
      order?.drop.point.lat ?? 28.57,
      order?.drop.point.lng ?? 77.32,
    );
    final driverPos = (driver?.hasLocation == true)
        ? LatLng(driver!.lat!, driver.lng!)
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureSheet();
      _ensureRoute(pickup, drop);
    });
    final linePoints = _route.length >= 2 ? _route : [pickup, drop];
    final fitPoints = [
      ...linePoints,
      ?driverPos,
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut),
        child: Stack(
          children: [
            Positioned.fill(
              child: GpGoogleMap(
                key: _mapKey,
                initialTarget: pickup,
                padding: EdgeInsets.only(bottom: _sheetHeight),
                markers: [
                  GpMapMarker(
                    id: 'pickup',
                    position: pickup,
                    hue: BitmapDescriptor.hueGreen,
                    title: 'Pickup',
                  ),
                  GpMapMarker(
                    id: 'drop',
                    position: drop,
                    hue: BitmapDescriptor.hueRed,
                    title: 'Drop',
                  ),
                  if (driverPos != null)
                    GpMapMarker(
                      id: 'driver',
                      position: driverPos,
                      hue: BitmapDescriptor.hueAzure,
                      title: driver?.name ?? 'Driver',
                    ),
                ],
                polylines: {routeLine(linePoints)},
                onMapCreated: (_) =>
                    _mapKey.currentState?.fitBounds(fitPoints),
              ),
            ),
            BookingMapFade(bottom: _sheetHeight),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    BookingRoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.go(RoutePaths.home),
                    ),
                    const Spacer(),
                    BookingGlassChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BookingStatusDot(
                            color: AppColors.success,
                            pulse: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Driver assigned',
                            style: AppTypography.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: BookingBottomSheet(
                key: _sheetKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BookingSheetHandle(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryLight,
                                Color(0xFFEFF6FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (driver?.name.isNotEmpty == true)
                                ? driver!.name[0].toUpperCase()
                                : 'D',
                            style: AppTypography.textTheme.headlineSmall
                                ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver?.displayName ?? 'Driver',
                                style: AppTypography.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${Formatters.rating(driver?.rating ?? 4.8)} ★ · ${driver?.vehicleLabel ?? 'Bike'} · ${driver?.plateNumber ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              Text(
                                (driver?.phone.isNotEmpty == true)
                                    ? driver!.displayPhone
                                    : 'Phone hidden',
                                style: AppTypography.textTheme.titleSmall
                                    ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if ((driver?.phone ?? '').isNotEmpty)
                          BookingRoundButton(
                            icon: Icons.call_rounded,
                            onTap: () => _callDriver(driver!.phone),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${driver?.etaMinutes ?? 12}',
                                style: AppTypography.textTheme.titleLarge
                                    ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'min',
                                style: AppTypography.textTheme.labelSmall
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (driverPos != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Live location updating on map',
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (order != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: BookingRouteStrip(
                          pickup: order.pickup.address,
                          drop: order.drop.address,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BookingOtpShareCards(
                        pickupOtp: order.pickupOtp,
                        deliveryOtp: order.deliveryOtp,
                        highlightPickup: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Tap OTP to copy',
                            style: AppTypography.textTheme.labelSmall,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              final text =
                                  'Pickup OTP: ${order.pickupOtp}\nDelivery OTP: ${order.deliveryOtp}';
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('OTPs copied'),
                                ),
                              );
                            },
                            child: const Text('Copy both'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    BookingPrimaryButton(
                      label: 'Track parcel',
                      onPressed: _cancelling ? null : _startTracking,
                    ),
                    if (order?.canCancelTrip == true) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _cancelling ? null : _cancelTrip,
                        child: _cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Cancel trip',
                                style: AppTypography.textTheme.labelLarge
                                    ?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
