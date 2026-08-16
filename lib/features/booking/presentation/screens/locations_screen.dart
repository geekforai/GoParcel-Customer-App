import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/gp_google_map.dart';
import '../../../../core/widgets/gp_places_field.dart';
import '../../../../domain/entities/order.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

enum _FocusField { pickup, drop }

class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  final _location = LocationService();
  final _directions = DirectionsService();
  final _mapKey = GlobalKey<GpGoogleMapState>();
  final _sheetKey = GlobalKey();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _pickupName = TextEditingController();
  final _pickupPhone = TextEditingController();
  final _dropName = TextEditingController();
  final _dropPhone = TextEditingController();
  String _pickupType = 'home';
  String _dropType = 'home';

  LatLng _center = LocationService.defaultNoida;
  LatLng? _pickupPoint;
  LatLng? _dropPoint;
  List<LatLng> _route = const [];
  String? _routeKey;
  _FocusField _focus = _FocusField.pickup;
  bool _loading = false;
  bool _locating = true;
  bool _movingFromPlace = false;
  double _sheetHeight = 300;
  Timer? _measureTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _pickupName.dispose();
    _pickupPhone.dispose();
    _dropName.dispose();
    _dropPhone.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    _measureTimer?.cancel();
    _measureTimer = Timer(const Duration(milliseconds: 40), () {
      final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !mounted) return;
      final h = box.size.height;
      if ((h - _sheetHeight).abs() > 2) {
        setState(() => _sheetHeight = h);
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _location.ensurePermission().timeout(const Duration(seconds: 3));
    } catch (_) {}
    LatLng here = LocationService.defaultNoida;
    try {
      here = await _location
          .currentLatLng()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _center = here;
      _pickupPoint = here;
      _locating = false;
    });
    final address = await _location.addressFromLatLng(here);
    if (!mounted) return;
    _pickupCtrl.text = address;
    await _mapKey.currentState?.animateTo(here);
    _scheduleMeasure();
  }

  Future<void> _useMyLocation() async {
    final here = await _location.currentLatLng();
    setState(() {
      _focus = _FocusField.pickup;
      _pickupPoint = here;
      _center = here;
    });
    await _mapKey.currentState?.animateTo(here);
    final address = await _location.addressFromLatLng(here);
    if (!mounted) return;
    _pickupCtrl.text = address;
  }

  Future<void> _onPlaceSelected(_FocusField field, PlaceDetails place) async {
    final point = LatLng(place.lat, place.lng);
    _movingFromPlace = true;
    setState(() {
      _center = point;
      if (field == _FocusField.pickup) {
        _pickupPoint = point;
        _focus = _FocusField.pickup;
      } else {
        _dropPoint = point;
        _focus = _FocusField.drop;
      }
    });
    await _mapKey.currentState?.animateTo(point, zoom: 15.5);
    _movingFromPlace = false;
    _scheduleMeasure();
  }

  void _onCameraIdle(LatLng center) async {
    if (_movingFromPlace) return;
    _center = center;
    final address = await _location.addressFromLatLng(center);
    if (!mounted) return;
    setState(() {
      if (_focus == _FocusField.pickup) {
        _pickupPoint = center;
        _pickupCtrl.text = address;
      } else {
        _dropPoint = center;
        _dropCtrl.text = address;
      }
    });
  }

  Future<void> _continue() async {
    final pickupAddr = _pickupCtrl.text.trim();
    final dropAddr = _dropCtrl.text.trim();
    if (pickupAddr.isEmpty || dropAddr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Select pickup and drop addresses'),
        ),
      );
      return;
    }
    if (_pickupPoint == null || _dropPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Pick both locations from search or map'),
        ),
      );
      return;
    }

    if (_pickupName.text.trim().isEmpty ||
        _dropName.text.trim().isEmpty ||
        _pickupPhone.text.trim().length != 10 ||
        _dropPhone.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Enter contact name and 10-digit phone for pickup and drop'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(bookingProvider.notifier).setLocations(
          pickup: PlaceLocation(
            label: _pickupType,
            address: pickupAddr,
            point: GeoPoint(
              lat: _pickupPoint!.latitude,
              lng: _pickupPoint!.longitude,
            ),
            contactName: _pickupName.text.trim(),
            contactPhone: _pickupPhone.text.trim(),
            addressType: _pickupType,
          ),
          drop: PlaceLocation(
            label: _dropType,
            address: dropAddr,
            point: GeoPoint(
              lat: _dropPoint!.latitude,
              lng: _dropPoint!.longitude,
            ),
            contactName: _dropName.text.trim(),
            contactPhone: _dropPhone.text.trim(),
            addressType: _dropType,
          ),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.push(RoutePaths.bookingParcel);
    } else {
      final msg =
          ref.read(bookingProvider).errorMessage ?? 'Unable to continue';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
      );
    }
  }

  List<GpMapMarker> get _markers {
    final list = <GpMapMarker>[];
    if (_pickupPoint != null) {
      list.add(GpMapMarker(
        id: 'pickup',
        position: _pickupPoint!,
        hue: BitmapDescriptor.hueGreen,
        title: 'Pickup',
      ));
    }
    if (_dropPoint != null) {
      list.add(GpMapMarker(
        id: 'drop',
        position: _dropPoint!,
        hue: BitmapDescriptor.hueRed,
        title: 'Drop',
      ));
    }
    return list;
  }

  Set<Polyline> get _polylines {
    if (_pickupPoint == null || _dropPoint == null) return {};
    final pts = _route.length >= 2 ? _route : [_pickupPoint!, _dropPoint!];
    return {routeLine(pts)};
  }

  Future<void> _ensureRoute() async {
    if (_pickupPoint == null || _dropPoint == null) return;
    final key =
        '${_pickupPoint!.latitude},${_pickupPoint!.longitude}->${_dropPoint!.latitude},${_dropPoint!.longitude}';
    if (_routeKey == key) return;
    _routeKey = key;
    final pts = await _directions.drivingRoute(
      origin: _pickupPoint!,
      destination: _dropPoint!,
    );
    if (!mounted || _routeKey != key) return;
    setState(() => _route = pts);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheet = MediaQuery.sizeOf(context).height * 0.78;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleMeasure();
      _ensureRoute();
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: _locating
                ? const ColoredBox(
                    color: Color(0xFFE8F0FE),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : GpGoogleMap(
                    key: _mapKey,
                    initialTarget: _center,
                    markers: _markers,
                    polylines: _polylines,
                    showCenterPin: true,
                    padding: EdgeInsets.only(bottom: _sheetHeight + keyboard),
                    onCameraIdle: _onCameraIdle,
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
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  BookingGlassChip(
                    child: Text(
                      'Set route',
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  BookingRoundButton(
                    icon: Icons.my_location_rounded,
                    onTap: _useMyLocation,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheet),
              child: Material(
                key: _sheetKey,
                color: Colors.transparent,
                child: BookingBottomSheet(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BookingSheetHandle(),
                        const SizedBox(height: 14),
                        Text(
                          'Where to send?',
                          style: AppTypography.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search an address or drag the map pin',
                          style: AppTypography.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              GpPlacesField(
                                controller: _pickupCtrl,
                                label: 'Pickup',
                                hintText: 'Search pickup address',
                                prefixIcon: Icons.radio_button_checked,
                                accentColor: AppColors.pickup,
                                onFocusChanged: (f) {
                                  if (f) {
                                    setState(
                                      () => _focus = _FocusField.pickup,
                                    );
                                  }
                                },
                                onPlaceSelected: (p) =>
                                    _onPlaceSelected(_FocusField.pickup, p),
                              ),
                              const SizedBox(height: 10),
                              GpPlacesField(
                                controller: _dropCtrl,
                                label: 'Drop',
                                hintText: 'Search drop address',
                                prefixIcon: Icons.location_on_rounded,
                                accentColor: AppColors.drop,
                                onFocusChanged: (f) {
                                  if (f) {
                                    setState(() => _focus = _FocusField.drop);
                                  }
                                },
                                onPlaceSelected: (p) =>
                                    _onPlaceSelected(_FocusField.drop, p),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _focus == _FocusField.pickup
                              ? 'Editing pickup on map'
                              : 'Editing drop on map',
                          textAlign: TextAlign.center,
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            color: _focus == _FocusField.pickup
                                ? AppColors.pickup
                                : AppColors.drop,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ContactBlock(
                          title: 'Pickup contact',
                          name: _pickupName,
                          phone: _pickupPhone,
                          type: _pickupType,
                          onType: (v) => setState(() => _pickupType = v),
                          onUseMyNumber: () {
                            final my = ref
                                    .read(sharedPreferencesProvider)
                                    .getString(AppConstants.phoneKey) ??
                                '';
                            setState(() => _pickupPhone.text = my);
                          },
                        ),
                        const SizedBox(height: 10),
                        _ContactBlock(
                          title: 'Drop contact',
                          name: _dropName,
                          phone: _dropPhone,
                          type: _dropType,
                          onType: (v) => setState(() => _dropType = v),
                          onUseMyNumber: () {
                            final my = ref
                                    .read(sharedPreferencesProvider)
                                    .getString(AppConstants.phoneKey) ??
                                '';
                            setState(() => _dropPhone.text = my);
                          },
                        ),
                        const SizedBox(height: 12),
                        BookingPrimaryButton(
                          label: 'Continue',
                          isLoading: _loading,
                          onPressed: _continue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.title,
    required this.name,
    required this.phone,
    required this.type,
    required this.onType,
    required this.onUseMyNumber,
  });

  final String title;
  final TextEditingController name;
  final TextEditingController phone;
  final String type;
  final ValueChanged<String> onType;
  final VoidCallback onUseMyNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Receiver name',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Phone',
            isDense: true,
            counterText: '',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onUseMyNumber,
            child: const Text('Use my number'),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final t in ['home', 'office', 'other'])
              ChoiceChip(
                label: Text(t[0].toUpperCase() + t.substring(1)),
                selected: type == t,
                onSelected: (_) => onType(t),
              ),
          ],
        ),
      ],
    );
  }
}
