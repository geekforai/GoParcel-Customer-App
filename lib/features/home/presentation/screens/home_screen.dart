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
import '../../../../core/locale/app_locale.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/services/recent_places_store.dart';
import '../../../../core/widgets/gp_google_map.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../booking/presentation/widgets/booking_ui.dart';

enum _FocusField { pickup, drop }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _location = LocationService();
  final _directions = DirectionsService();
  final _places = PlacesService();
  final _mapKey = GlobalKey<GpGoogleMapState>();
  final _sheetKey = GlobalKey();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();

  LatLng _center = LocationService.defaultJaipur;
  LatLng? _pickupPoint;
  LatLng? _dropPoint;
  List<LatLng> _route = const [];
  String? _routeKey;
  _FocusField _focus = _FocusField.drop;
  bool _loading = false;
  bool _locating = true;
  bool _searching = false;
  double _sheetHeight = 280;
  Timer? _measureTimer;
  Timer? _searchTimer;
  List<PlaceSuggestion> _suggestions = const [];
  List<SavedAddress> _saved = const [];
  List<RecentPlace> _recent = const [];
  String _contactName = 'Customer';
  String _contactPhone = '';

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(_onFocusChange);
    _dropFocus.addListener(_onFocusChange);
    _pickupCtrl.addListener(_onQueryChanged);
    _dropCtrl.addListener(_onQueryChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _searchTimer?.cancel();
    _pickupFocus.removeListener(_onFocusChange);
    _dropFocus.removeListener(_onFocusChange);
    _pickupCtrl.removeListener(_onQueryChanged);
    _dropCtrl.removeListener(_onQueryChanged);
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final searching = _pickupFocus.hasFocus || _dropFocus.hasFocus;
    setState(() {
      _searching = searching;
      if (_pickupFocus.hasFocus) _focus = _FocusField.pickup;
      if (_dropFocus.hasFocus) _focus = _FocusField.drop;
    });
    _scheduleSearch();
    _scheduleMeasure();
  }

  void _onQueryChanged() {
    if (!_searching) return;
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _activeController.text.trim();
    if (!mounted) return;
    if (query.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    final list = await _places.autocomplete(query);
    if (!mounted) return;
    if (_activeController.text.trim() != query) return;
    setState(() => _suggestions = list);
  }

  TextEditingController get _activeController =>
      _focus == _FocusField.pickup ? _pickupCtrl : _dropCtrl;

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
    final prefs = ref.read(sharedPreferencesProvider);
    _recent = RecentPlacesStore(prefs).read();
    final sessionResult = await ref.read(authRepositoryProvider).getSession();
    sessionResult.when(
      success: (s) {
        _contactName = s.fullName.isEmpty ? 'Customer' : s.fullName;
        _contactPhone = _tenDigits(s.phone);
      },
      failure: (_) {},
    );
    if (_contactPhone.isEmpty) {
      _contactPhone = _tenDigits(prefs.getString(AppConstants.phoneKey) ?? '');
    }

    ref.read(customerRepositoryProvider).getSavedAddresses().then((result) {
      result.when(
        success: (list) {
          if (mounted) setState(() => _saved = list);
        },
        failure: (_) {},
      );
    });

    try {
      await _location.ensurePermission().timeout(const Duration(seconds: 3));
    } catch (_) {}
    LatLng here = LocationService.defaultJaipur;
    try {
      here = await _location.currentLatLng().timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _center = here;
      _pickupPoint = here;
      _locating = false;
    });
    final address = await _location.addressFromLatLng(here);
    if (!mounted) return;
    if (_pickupCtrl.text.isEmpty) _pickupCtrl.text = address;
    await _mapKey.currentState?.animateTo(here);
    _scheduleMeasure();
  }

  String _tenDigits(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 10) return d.substring(d.length - 10);
    return d;
  }

  Future<void> _useCurrentLocation() async {
    final here = await _location.currentLatLng();
    final address = await _location.addressFromLatLng(here);
    if (!mounted) return;
    await _applyPoint(address: address, point: here, saveRecent: false);
  }

  Future<void> _applyPoint({
    required String address,
    required LatLng point,
    bool saveRecent = true,
  }) async {
    setState(() {
      _center = point;
      if (_focus == _FocusField.pickup) {
        _pickupPoint = point;
        _pickupCtrl.text = address;
      } else {
        _dropPoint = point;
        _dropCtrl.text = address;
      }
      _suggestions = const [];
      _searching = false;
    });
    _pickupFocus.unfocus();
    _dropFocus.unfocus();
    await _mapKey.currentState?.animateTo(point, zoom: 15.5);
    if (saveRecent) {
      final store = RecentPlacesStore(ref.read(sharedPreferencesProvider));
      await store.add(
        RecentPlace(address: address, lat: point.latitude, lng: point.longitude),
      );
      if (mounted) setState(() => _recent = store.read());
    }
    _scheduleMeasure();
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final details = await _places.details(suggestion.placeId);
    if (!mounted || details == null) return;
    await _applyPoint(
      address: details.address.isEmpty ? suggestion.description : details.address,
      point: LatLng(details.lat, details.lng),
    );
  }

  Future<void> _selectSaved(SavedAddress saved) async {
    final point = await _location.latLngFromAddress(saved.address);
    if (!mounted) return;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not locate this address'),
        ),
      );
      return;
    }
    await _applyPoint(address: saved.address, point: point);
  }

  Future<void> _selectRecent(RecentPlace place) async {
    await _applyPoint(
      address: place.address,
      point: LatLng(place.lat, place.lng),
      saveRecent: true,
    );
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
          content: Text('Pick both locations from search'),
        ),
      );
      return;
    }
    final phone = _tenDigits(_contactPhone);
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Add a valid phone number in your profile'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await ref.read(bookingProvider.notifier).setLocations(
          pickup: PlaceLocation(
            label: 'Pickup',
            address: pickupAddr,
            point: GeoPoint(
              lat: _pickupPoint!.latitude,
              lng: _pickupPoint!.longitude,
            ),
            contactName: _contactName,
            contactPhone: phone,
            addressType: 'home',
          ),
          drop: PlaceLocation(
            label: 'Drop',
            address: dropAddr,
            point: GeoPoint(
              lat: _dropPoint!.latitude,
              lng: _dropPoint!.longitude,
            ),
            contactName: _contactName,
            contactPhone: phone,
            addressType: 'home',
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

  List<SavedAddress> get _filteredSaved {
    final q = _activeController.text.trim().toLowerCase();
    if (q.isEmpty) return _saved;
    return _saved
        .where(
          (a) =>
              a.label.toLowerCase().contains(q) ||
              a.address.toLowerCase().contains(q),
        )
        .toList();
  }

  List<RecentPlace> get _filteredRecent {
    final q = _activeController.text.trim().toLowerCase();
    if (q.isEmpty) return _recent;
    return _recent.where((p) => p.address.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheet = MediaQuery.sizeOf(context).height * (_searching ? 0.72 : 0.52);
    final active = ref.watch(bookingProvider).order;
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
                    showCenterPin: !_searching,
                    padding: EdgeInsets.only(bottom: _sheetHeight + keyboard),
                    onCameraIdle: _searching
                        ? null
                        : (center) async {
                            _center = center;
                          },
                  ),
          ),
          BookingMapFade(bottom: _sheetHeight),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  BookingGlassChip(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Jaipur',
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  BookingRoundButton(
                    icon: Icons.my_location_rounded,
                    onTap: () async {
                      setState(() => _focus = _FocusField.pickup);
                      await _useCurrentLocation();
                    },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: _searching ? maxSheet : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheet),
                child: Material(
                  key: _sheetKey,
                  color: Colors.transparent,
                  child: BookingBottomSheet(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize:
                          _searching ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BookingSheetHandle(),
                        if (active?.isBlockingNewBooking ?? false) ...[
                          const SizedBox(height: 10),
                          _ActiveTripBanner(
                            label: s.continueTrip,
                            onTap: () => context.push(active!.resumeRoute),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          s.whereTo,
                          style: AppTypography.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        _RouteCard(
                          pickupCtrl: _pickupCtrl,
                          dropCtrl: _dropCtrl,
                          pickupFocus: _pickupFocus,
                          dropFocus: _dropFocus,
                          pickupHint: s.searchPickup,
                          dropHint: s.searchDrop,
                          pickupLabel: s.pickup,
                          dropLabel: s.drop,
                        ),
                        if (_searching) ...[
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _SuggestTile(
                                  icon: Icons.my_location_rounded,
                                  color: AppColors.pickup,
                                  title: s.currentLocation,
                                  subtitle: 'Use GPS',
                                  onTap: _useCurrentLocation,
                                ),
                                if (_filteredSaved.isNotEmpty) ...[
                                  _SectionLabel(s.savedPlaces),
                                  for (final a in _filteredSaved.take(6))
                                    _SuggestTile(
                                      icon: a.label.toLowerCase() == 'work'
                                          ? Icons.work_rounded
                                          : Icons.home_rounded,
                                      color: AppColors.primary,
                                      title: a.label,
                                      subtitle: a.address,
                                      onTap: () => _selectSaved(a),
                                    ),
                                ],
                                if (_filteredRecent.isNotEmpty) ...[
                                  _SectionLabel(s.recentSearches),
                                  for (final p in _filteredRecent.take(6))
                                    _SuggestTile(
                                      icon: Icons.history_rounded,
                                      color: AppColors.textTertiary,
                                      title: p.address,
                                      onTap: () => _selectRecent(p),
                                    ),
                                ],
                                if (_suggestions.isNotEmpty) ...[
                                  _SectionLabel(s.searchDrop),
                                  for (final p in _suggestions.take(8))
                                    _SuggestTile(
                                      icon: Icons.place_outlined,
                                      color: AppColors.drop,
                                      title: p.mainText.isEmpty
                                          ? p.description
                                          : p.mainText,
                                      subtitle: p.secondaryText,
                                      onTap: () => _selectSuggestion(p),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 14),
                          BookingPrimaryButton(
                            label: s.continueLabel,
                            isLoading: _loading,
                            onPressed: _continue,
                          ),
                        ],
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

class _ActiveTripBanner extends StatelessWidget {
  const _ActiveTripBanner({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickupCtrl,
    required this.dropCtrl,
    required this.pickupFocus,
    required this.dropFocus,
    required this.pickupHint,
    required this.dropHint,
    required this.pickupLabel,
    required this.dropLabel,
  });

  final TextEditingController pickupCtrl;
  final TextEditingController dropCtrl;
  final FocusNode pickupFocus;
  final FocusNode dropFocus;
  final String pickupHint;
  final String dropHint;
  final String pickupLabel;
  final String dropLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SearchRow(
            controller: pickupCtrl,
            focusNode: pickupFocus,
            hint: pickupHint,
            label: pickupLabel,
            color: AppColors.pickup,
            icon: Icons.radio_button_checked,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 14,
                child: VerticalDivider(width: 2, thickness: 2),
              ),
            ),
          ),
          _SearchRow(
            controller: dropCtrl,
            focusNode: dropFocus,
            hint: dropHint,
            label: dropLabel,
            color: AppColors.drop,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.label,
    required this.color,
    required this.icon,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              labelText: label,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _SuggestTile extends StatelessWidget {
  const _SuggestTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }
}
