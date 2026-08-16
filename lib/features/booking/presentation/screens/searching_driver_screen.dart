import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gp_google_map.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

class SearchingDriverScreen extends ConsumerStatefulWidget {
  const SearchingDriverScreen({super.key});

  @override
  ConsumerState<SearchingDriverScreen> createState() =>
      _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends ConsumerState<SearchingDriverScreen>
    with TickerProviderStateMixin {
  final _mapKey = GlobalKey<GpGoogleMapState>();
  final _sheetKey = GlobalKey();
  final _directions = DirectionsService();
  late int _seconds;
  late final int _totalSeconds;
  Timer? _timer;
  bool _assigned = false;
  bool _polling = false;
  bool _cancelling = false;
  bool _timedOut = false;
  String? _lastSnack;
  double _sheetHeight = 300;
  List<LatLng> _route = const [];
  String? _routeKey;

  late final AnimationController _pulse;
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _totalSeconds = AppConstants.searchDriverSeconds;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _startTimer(_totalSeconds);
    WidgetsBinding.instance.addPostFrameCallback((_) => _assign());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingProvider.notifier).refreshActiveTrip();
    });
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timedOut = false;
    _seconds = seconds;
    if (!_pulse.isAnimating) _pulse.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted || _assigned) return;
      if (_seconds > 0) {
        setState(() => _seconds--);
        if (_seconds % 2 == 0) await _assign();
      } else {
        t.cancel();
        _pulse.stop();
        setState(() => _timedOut = true);
      }
    });
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

  Future<void> _assign() async {
    if (_assigned || _polling || _cancelling) return;
    _polling = true;
    final ok = await ref.read(bookingProvider.notifier).assignDriver();
    _polling = false;
    if (!mounted) return;
    if (ok) {
      _assigned = true;
      _timer?.cancel();
      _pulse.stop();
      context.go(RoutePaths.bookingDriver);
      return;
    }
    final err = ref.read(bookingProvider).errorMessage;
    if (err != null && err.isNotEmpty && err != _lastSnack && !_timedOut) {
      _lastSnack = err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, _sheetHeight + 12),
          content: Text(err),
        ),
      );
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CancelSheet(
        onKeep: () => Navigator.pop(ctx, false),
        onCancel: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    _timer?.cancel();
    _pulse.stop();
    final ok = await ref.read(bookingProvider.notifier).cancel();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      context.go(RoutePaths.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            ref.read(bookingProvider).errorMessage ?? 'Could not cancel',
          ),
        ),
      );
    }
  }

  void _keepSearching() {
    _startTimer(AppConstants.searchDriverSeconds);
    setState(() {});
    _assign();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingProvider).order;
    final pickup = LatLng(
      order?.pickup.point.lat ?? 28.62,
      order?.pickup.point.lng ?? 77.36,
    );
    final drop = LatLng(
      order?.drop.point.lat ?? 28.57,
      order?.drop.point.lng ?? 77.32,
    );
    final progress =
        _timedOut ? 0.0 : (_seconds / _totalSeconds).clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureSheet();
      _ensureRoute(pickup, drop);
    });
    final linePoints = _route.length >= 2 ? _route : [pickup, drop];

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
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
                ],
                polylines: {routeLine(linePoints)},
                onMapCreated: (_) => _mapKey.currentState?.fitBounds(
                  linePoints.length >= 2 ? linePoints : [pickup, drop],
                ),
              ),
            ),
            // Soft vignette so map + sheet feel connected
            Positioned(
              left: 0,
              right: 0,
              bottom: _sheetHeight - 40,
              height: 80,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _GlassChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _timedOut
                                  ? AppColors.warning
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timedOut ? 'Still waiting' : 'Finding driver',
                            style: AppTypography.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _GlassIconButton(
                      icon: Icons.close_rounded,
                      onTap: _cancelling ? null : _cancel,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _SearchSheet(
                key: _sheetKey,
                orderFare: order == null
                    ? null
                    : Formatters.currency(order.fare),
                pickupAddress: order?.pickup.address,
                dropAddress: order?.drop.address,
                pickupOtp: order?.pickupOtp ?? '',
                deliveryOtp: order?.deliveryOtp ?? '',
                timedOut: _timedOut,
                seconds: _seconds,
                progress: progress,
                pulse: _pulse,
                cancelling: _cancelling,
                onCancel: _cancel,
                onKeepSearching: _keepSearching,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSheet extends StatelessWidget {
  const _SearchSheet({
    super.key,
    required this.orderFare,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupOtp,
    required this.deliveryOtp,
    required this.timedOut,
    required this.seconds,
    required this.progress,
    required this.pulse,
    required this.cancelling,
    required this.onCancel,
    required this.onKeepSearching,
  });

  final String? orderFare;
  final String? pickupAddress;
  final String? dropAddress;
  final String pickupOtp;
  final String deliveryOtp;
  final bool timedOut;
  final int seconds;
  final double progress;
  final AnimationController pulse;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onKeepSearching;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (!timedOut) ...[
                  Center(
                    child: SizedBox(
                      width: 108,
                      height: 108,
                      child: AnimatedBuilder(
                        animation: pulse,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _RadarPainter(
                              t: pulse.value,
                              color: AppColors.primary,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 5,
                                        backgroundColor: AppColors.primaryLight,
                                        color: AppColors.primary,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$seconds',
                                          style: AppTypography
                                              .textTheme.headlineMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                        ),
                                        Text(
                                          'sec',
                                          style: AppTypography
                                              .textTheme.labelSmall
                                              ?.copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Matching nearby drivers',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hang tight — we’re pinging drivers around your pickup',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyMedium,
                  ),
                ] else ...[
                  const Center(
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      size: 40,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No driver yet',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try again — more drivers may come online soon',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyMedium,
                  ),
                ],
                if (orderFare != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF8FAFF),
                          Color(0xFFEFF6FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          orderFare!,
                          style:
                              AppTypography.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RouteStrip(
                          pickup: pickupAddress ?? 'Pickup',
                          drop: dropAddress ?? 'Drop',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                BookingOtpShareCards(
                  pickupOtp: pickupOtp,
                  deliveryOtp: deliveryOtp,
                ),
                const SizedBox(height: 16),
                if (!timedOut)
                  TextButton(
                    onPressed: cancelling ? null : onCancel,
                    child: cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Cancel booking',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: cancelling ? null : onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: onKeepSearching,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Keep searching',
                              style: AppTypography.textTheme.labelLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.pickup, required this.drop});

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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                drop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = 18 + phase * (size.width / 2 - 8);
      final opacity = (1 - phase) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 1.5,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.onKeep, required this.onCancel});
  final VoidCallback onKeep;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cancel this booking?',
              style: AppTypography.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nearby drivers will stop seeing this request.',
              style: AppTypography.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onKeep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Keep searching'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  'Yes booking',
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
