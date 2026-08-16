import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme/app_colors.dart';
import '../debug/agent_log.dart';

class GpMapMarker {
  const GpMapMarker({
    required this.id,
    required this.position,
    required this.hue,
    this.title,
  });

  final String id;
  final LatLng position;
  final double hue;
  final String? title;
}

/// Full-bleed Google Map used across booking / tracking screens.
class GpGoogleMap extends StatefulWidget {
  const GpGoogleMap({
    super.key,
    this.initialTarget = const LatLng(28.6200, 77.3650),
    this.initialZoom = 14.5,
    this.markers = const [],
    this.polylines = const {},
    this.myLocationEnabled = true,
    this.onMapCreated,
    this.onCameraIdle,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.showCenterPin = false,
    this.interactive = true,
  });

  final LatLng initialTarget;
  final double initialZoom;
  final List<GpMapMarker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;
  final void Function(GoogleMapController controller)? onMapCreated;
  final void Function(LatLng center)? onCameraIdle;
  final void Function(LatLng point)? onTap;
  final EdgeInsets padding;
  final bool showCenterPin;
  final bool interactive;

  @override
  State<GpGoogleMap> createState() => GpGoogleMapState();
}

class GpGoogleMapState extends State<GpGoogleMap> {
  GoogleMapController? _controller;
  bool _ready = false;
  Timer? _readyTimeout;

  @override
  void initState() {
    super.initState();
    // #region agent log
    agentLog(
      'gp_google_map',
      'map init',
      hypothesisId: 'I',
      runId: 'post-fix',
      data: {'app': 'customer'},
    );
    // #endregion
    // Maps SDK can hang forever if key/API disabled — never block UI.
    _readyTimeout = Timer(const Duration(seconds: 2), () {
      if (!mounted || _ready) return;
      // #region agent log
      agentLog(
        'gp_google_map',
        'map ready timeout fallback',
        hypothesisId: 'I',
        runId: 'post-fix',
        data: {'ms': 2000},
      );
      // #endregion
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    super.dispose();
  }

  Future<void> animateTo(LatLng target, {double zoom = 15}) async {
    final c = _controller;
    if (c == null) return;
    await c.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Future<void> fitBounds(List<LatLng> points, {double padding = 72}) async {
    final c = _controller;
    if (c == null || points.isEmpty) return;
    if (points.length == 1) {
      await animateTo(points.first);
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding,
      ),
    );
  }

  Set<Marker> get _markers => widget.markers
      .map(
        (m) => Marker(
          markerId: MarkerId(m.id),
          position: m.position,
          infoWindow: m.title == null ? InfoWindow.noText : InfoWindow(title: m.title),
          icon: BitmapDescriptor.defaultMarkerWithHue(m.hue),
        ),
      )
      .toSet();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialTarget,
            zoom: widget.initialZoom,
          ),
          markers: _markers,
          polylines: widget.polylines,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          indoorViewEnabled: false,
          buildingsEnabled: false,
          trafficEnabled: false,
          liteModeEnabled: false,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          padding: widget.padding,
          onMapCreated: (controller) {
            _readyTimeout?.cancel();
            _controller = controller;
            setState(() => _ready = true);
            // #region agent log
            agentLog(
              'gp_google_map',
              'map created',
              hypothesisId: 'I',
              runId: 'post-fix',
              data: {'app': 'customer'},
            );
            // #endregion
            widget.onMapCreated?.call(controller);
          },
          onCameraIdle: () async {
            if (widget.onCameraIdle == null || _controller == null) return;
            final bounds = await _controller!.getVisibleRegion();
            final center = LatLng(
              (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
              (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
            );
            widget.onCameraIdle!(center);
          },
          onTap: widget.onTap,
        ),
        if (!_ready)
          const ColoredBox(
            color: Color(0xFFE8F0FE),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        if (widget.showCenterPin)
          Positioned.fill(
            child: Padding(
              padding: widget.padding,
              child: const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Polyline routeLine(List<LatLng> points, {Color color = AppColors.mapBlue}) {
  return Polyline(
    polylineId: const PolylineId('route'),
    color: color,
    width: 5,
    points: points,
    jointType: JointType.round,
    endCap: Cap.roundCap,
    startCap: Cap.roundCap,
  );
}
