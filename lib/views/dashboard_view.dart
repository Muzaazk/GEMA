import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/map_tiles.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../viewmodels/location_viewmodel.dart';
import 'widgets/danger_flash_overlay.dart';
import 'widgets/emergency_alert_modal.dart';
import 'widgets/gema_app_bar_title.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const LatLng _defaultCenter = LatLng(-6.200000, 106.816666);
  static const List<double> _sheetSnapSizes = [0.12, 0.34, 0.72];

  String? _selectedPerlintasanId;
  bool _followUserLocation = true;
  bool _isAnimatingCamera = false;
  int _cameraAnimationToken = 0;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _animateCamera({
    required LatLng target,
    required double zoom,
  }) async {
    if (!mounted) return;

    final token = ++_cameraAnimationToken;
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    setState(() => _isAnimatingCamera = true);

    const panSteps = 4;
    for (var i = 1; i <= panSteps; i++) {
      if (!mounted || token != _cameraAnimationToken) return;
      final t = Curves.easeInOut.transform(i / panSteps);
      final lat =
          startCenter.latitude + (target.latitude - startCenter.latitude) * t;
      final lng =
          startCenter.longitude + (target.longitude - startCenter.longitude) * t;
      _mapController.move(LatLng(lat, lng), startZoom);
      await Future<void>.delayed(const Duration(milliseconds: 75));
    }

    const zoomSteps = 3;
    for (var i = 1; i <= zoomSteps; i++) {
      if (!mounted || token != _cameraAnimationToken) return;
      final t = Curves.easeInOut.transform(i / zoomSteps);
      final z = startZoom + (zoom - startZoom) * t;
      _mapController.move(target, z);
      await Future<void>.delayed(const Duration(milliseconds: 85));
    }

    if (mounted && token == _cameraAnimationToken) {
      setState(() => _isAnimatingCamera = false);
    }
  }

  double _zoomForRadius(double latitude, double radiusMeters) {
    final latRad = latitude * math.pi / 180;
    final diameterMeters = radiusMeters * 2.8;
    final metersPerPixel = diameterMeters / 360;
    final zoom =
        math.log(156543.03 * math.cos(latRad) / metersPerPixel) / math.ln2;
    return zoom.clamp(12.5, 17.5);
  }

  Future<void> _focusOnPerlintasan(Perlintasan perlintasan) async {
    setState(() {
      _selectedPerlintasanId = perlintasan.id;
      _followUserLocation = false;
    });

    final target = LatLng(perlintasan.latitude, perlintasan.longitude);
    final zoom = _zoomForRadius(
      perlintasan.latitude,
      perlintasan.radiusBahayaMeter.toDouble(),
    );

    await _animateCamera(target: target, zoom: zoom);
  }

  void _onSheetDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final delta = -details.primaryDelta! / screenHeight;
    _sheetController.jumpTo((_sheetController.size + delta).clamp(0.12, 0.72));
  }

  void _onSheetDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    final nearest = _sheetSnapSizes.reduce(
      (a, b) => (a - current).abs() < (b - current).abs() ? a : b,
    );
    _sheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  List<CircleMarker> _buildCircles(LocationState state) {
    final circles = <CircleMarker>[];

    if (state.currentPosition != null) {
      circles.add(
        CircleMarker(
          point: LatLng(
            state.currentPosition!.latitude,
            state.currentPosition!.longitude,
          ),
          radius: 12,
          useRadiusInMeter: true,
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          borderColor: Colors.white,
          borderStrokeWidth: 2.5,
        ),
      );
    }

    for (final p in state.perlintasanList) {
      final point = LatLng(p.latitude, p.longitude);
      final isSelected = p.id == _selectedPerlintasanId;

      circles.add(
        CircleMarker(
          point: point,
          radius: p.radiusBahayaMeter.toDouble(),
          useRadiusInMeter: true,
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.22)
              : AppTheme.dangerColor.withValues(alpha: 0.18),
          borderColor: isSelected
              ? AppTheme.primaryColor
              : AppTheme.dangerColor.withValues(alpha: 0.55),
          borderStrokeWidth: isSelected ? 2.5 : 1.5,
        ),
      );

      circles.add(
        CircleMarker(
          point: point,
          radius: 8,
          useRadiusInMeter: true,
          color: isSelected ? AppTheme.primaryColor : AppTheme.dangerColor,
          borderColor: Colors.white,
          borderStrokeWidth: 1.5,
        ),
      );
    }

    return circles;
  }

  List<Marker> _buildMarkers(LocationState state) {
    return state.perlintasanList.map((p) {
      final isSelected = p.id == _selectedPerlintasanId;
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 140,
        height: 36,
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE3F2FD)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: isSelected ? 1.5 : 0,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          child: Text(
            p.nama,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.primaryColor : Colors.black87,
            ),
          ),
        ),
      );
    }).toList();
  }

  LatLng _initialCenter(LocationState state) {
    if (state.currentPosition != null) {
      return LatLng(
        state.currentPosition!.latitude,
        state.currentPosition!.longitude,
      );
    }
    return _defaultCenter;
  }

  Widget _buildSheetHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onSheetDragUpdate,
      onVerticalDragEnd: _onSheetDragEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 56,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Perlintasan Terdekat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerlintasanCard({
    required Perlintasan p,
    required bool isSelected,
    required String distanceStr,
    required VoidCallback onTap,
  }) {
    const selectedBlue = Color(0xFFE3F2FD);
    const selectedBorder = Color(0xFF90CAF9);

    return Material(
      color: isSelected ? selectedBlue : Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? selectedBorder : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFBBDEFB)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.train,
                  color: isSelected ? AppTheme.primaryColor : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nama,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      distanceStr.isNotEmpty
                          ? distanceStr
                          : 'Menghitung jarak...',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.my_location_rounded,
                size: 18,
                color: isSelected ? AppTheme.primaryColor : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationViewModelProvider);
    final sortedPerlintasan = [...locationState.perlintasanList];
    sortedPerlintasan.sort((a, b) {
      final current = locationState.currentPosition;
      if (current == null) return a.nama.compareTo(b.nama);
      final distanceA = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        a.latitude,
        a.longitude,
      );
      final distanceB = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        b.latitude,
        b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    ref.listen<LocationState>(locationViewModelProvider, (previous, next) {
      final prev = previous?.currentPosition;
      final curr = next.currentPosition;
      if (curr == null || !_followUserLocation || _isAnimatingCamera) {
        return;
      }

      final positionChanged =
          prev?.latitude != curr.latitude || prev?.longitude != curr.longitude;

      if (positionChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(
            LatLng(curr.latitude, curr.longitude),
            _mapController.camera.zoom,
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const GemaAppBarTitle(),
        actions: [
          if (!_followUserLocation)
            IconButton(
              tooltip: 'Kembali ke lokasi saya',
              onPressed: () {
                final pos = locationState.currentPosition;
                if (pos == null) return;
                setState(() {
                  _followUserLocation = true;
                  _selectedPerlintasanId = null;
                });
                _animateCamera(
                  target: LatLng(pos.latitude, pos.longitude),
                  zoom: 14,
                );
              },
              icon: const Icon(Icons.my_location_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter(locationState),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              MapTiles.buildLayer(),
              MapTiles.buildAttribution(),
              CircleLayer(circles: _buildCircles(locationState)),
              MarkerLayer(markers: _buildMarkers(locationState)),
              if (locationState.currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        locationState.currentPosition!.latitude,
                        locationState.currentPosition!.longitude,
                      ),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: locationState.isDanger
                    ? AppTheme.dangerColor
                    : AppTheme.safeColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    locationState.isDanger
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locationState.isDanger
                        ? 'Status: Area Bahaya'
                        : 'Status: Area Aman',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.34,
            minChildSize: 0.12,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: _sheetSnapSizes,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSheetHeader(),
                    Expanded(
                      child: sortedPerlintasan.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: sortedPerlintasan.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final p = sortedPerlintasan[index];
                                final isSelected =
                                    p.id == _selectedPerlintasanId;

                                String distanceStr = '';
                                if (locationState.currentPosition != null) {
                                  final dist = Geolocator.distanceBetween(
                                    locationState.currentPosition!.latitude,
                                    locationState.currentPosition!.longitude,
                                    p.latitude,
                                    p.longitude,
                                  );
                                  distanceStr =
                                      '${(dist / 1000).toStringAsFixed(1)} km';
                                }

                                return _buildPerlintasanCard(
                                  p: p,
                                  isSelected: isSelected,
                                  distanceStr: distanceStr,
                                  onTap: () => _focusOnPerlintasan(p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (locationState.isDanger)
            const Positioned.fill(child: DangerFlashOverlay()),
          if (locationState.showDangerAlert)
            const Positioned.fill(child: EmergencyAlertModal()),
        ],
      ),
    );
  }
}
