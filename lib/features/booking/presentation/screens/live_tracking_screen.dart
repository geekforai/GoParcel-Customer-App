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
import '../../../../core/widgets/gp_google_map.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _mapKey = GlobalKey<GpGoogleMapState>();
  final _sheetKey = GlobalKey();
  final _directions = DirectionsService();
  bool _loading = false;
  bool _cancelling = false;
  double _sheetHeight = 280;
  List<LatLng> _route = const [];
  String? _routeKey;
  Timer? _poll;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
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
    _pulse.dispose();
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

  Future<void> _markDelivered() async {
    setState(() => _loading = true);
    final ok = await ref.read(bookingProvider.notifier).markDelivered();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) context.go(RoutePaths.bookingCompleted);
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: const Text(
          'You can cancel until the driver picks up the parcel.',
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
    await launchUrl(Uri(scheme: 'tel', path: cleaned));
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingProvider).order;
    final driver = order?.driver;
    final eta = driver?.etaMinutes ?? 18;
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
      body: Stack(
        children: [
          Positioned.fill(
            child: GpGoogleMap(
              key: _mapKey,
              initialTarget: drop,
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
                    icon: Icons.close_rounded,
                    onTap: () => context.go(RoutePaths.home),
                  ),
                  const Spacer(),
                  BookingGlassChip(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.55 + _pulse.value * 0.45,
                                ),
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live tracking',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: order?.canCancelTrip == true
                              ? AppColors.primaryLight
                              : AppColors.successLight,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          order?.canCancelTrip == true
                              ? 'Driver en route'
                              : 'In transit',
                          style: AppTypography.textTheme.labelMedium?.copyWith(
                            color: order?.canCancelTrip == true
                                ? AppColors.primary
                                : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ETA ',
                        style: AppTypography.textTheme.bodyMedium,
                      ),
                      Text(
                        '$eta min',
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (driver?.name.isNotEmpty == true)
                              ? driver!.name[0].toUpperCase()
                              : 'D',
                          style: AppTypography.textTheme.titleLarge?.copyWith(
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
                              driver?.name ?? 'Driver',
                              style: AppTypography.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${driver?.vehicleLabel ?? 'On the way'} · ${driver?.plateNumber ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.textTheme.bodySmall,
                            ),
                            Text(
                              (driver?.phone.isNotEmpty == true)
                                  ? driver!.phone
                                  : 'Phone updating…',
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
                    ],
                  ),
                  if (driverPos != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '● Live driver location on map',
                      style: AppTypography.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (order != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: BookingRouteStrip(
                        pickup: order.pickup.address,
                        drop: order.drop.address,
                      ),
                    ),
                    const SizedBox(height: 14),
                    BookingOtpShareCards(
                      pickupOtp: order.pickupOtp,
                      deliveryOtp: order.deliveryOtp,
                      highlightPickup: false,
                      highlightDelivery: true,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text:
                                'Pickup OTP: ${order.pickupOtp}\nDelivery OTP: ${order.deliveryOtp}\nDriver: ${driver?.phone ?? ''}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Details copied'),
                            ),
                          );
                        },
                        child: const Text('Copy details'),
                      ),
                    ),
                  ],
                  BookingPrimaryButton(
                    label: order?.canCancelTrip == true
                        ? 'Waiting for pickup'
                        : 'Mark delivered',
                    isLoading: _loading,
                    color: order?.canCancelTrip == true
                        ? AppColors.primary
                        : AppColors.success,
                    onPressed: order?.canCancelTrip == true
                        ? null
                        : (_cancelling ? null : _markDelivered),
                  ),
                  if (order?.canCancelTrip == true) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: (_loading || _cancelling) ? null : _cancelTrip,
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
    );
  }
}
