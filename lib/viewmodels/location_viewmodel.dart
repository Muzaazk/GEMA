import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider((ref) => LocationService());
final apiServiceProvider = Provider((ref) => ApiService());

final locationViewModelProvider =
    StateNotifierProvider<LocationViewModel, LocationState>((ref) {
      return LocationViewModel(
        ref.read(locationServiceProvider),
        ref.read(apiServiceProvider),
      );
    });

class LocationState {
  final Position? currentPosition;
  final List<Perlintasan> perlintasanList;
  final bool isDanger;
  final bool showDangerAlert;
  final Perlintasan? nearestPerlintasan;
  final bool showDangerOverlay;

  LocationState({
    this.currentPosition,
    this.perlintasanList = const [],
    this.isDanger = false,
    this.showDangerAlert = false,
    this.nearestPerlintasan,
    this.showDangerOverlay = false,
  });

  LocationState copyWith({
    Position? currentPosition,
    List<Perlintasan>? perlintasanList,
    bool? isDanger,
    bool? showDangerAlert,
    Perlintasan? nearestPerlintasan,
    bool? showDangerOverlay,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      perlintasanList: perlintasanList ?? this.perlintasanList,
      isDanger: isDanger ?? this.isDanger,
      showDangerAlert: showDangerAlert ?? this.showDangerAlert,
      nearestPerlintasan: nearestPerlintasan ?? this.nearestPerlintasan,
      showDangerOverlay: showDangerOverlay ?? this.showDangerOverlay,
    );
  }
}

class LocationViewModel extends StateNotifier<LocationState> {
  final LocationService _locationService;
  final ApiService _apiService;
  StreamSubscription<Position>? _positionSubscription;
  bool _alertAcknowledged = false;

  LocationViewModel(this._locationService, this._apiService)
    : super(LocationState()) {
    _init();
  }

  Future<void> _init() async {
    final list = await _apiService.getPerlintasan();
    state = state.copyWith(perlintasanList: list);

    final initialLoc = await _locationService.getCurrentLocation();
    if (initialLoc != null) {
      _processNewLocation(initialLoc);
    }

    final hasPermission = await _locationService.handlePermission();
    if (hasPermission) {
      _positionSubscription = _locationService.getLocationStream().listen(
        _processNewLocation,
      );
    }
  }

  void _processNewLocation(Position position) {
    var danger = false;
    Perlintasan? nearest;
    double minDistance = double.infinity;
    const enterThreshold = 1.0;
    const exitThreshold = 1.15;

    for (var p in state.perlintasanList) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        p.latitude,
        p.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = p;
      }

      final radius = p.radiusBahayaMeter.toDouble();
      final threshold = state.isDanger
          ? radius * exitThreshold
          : radius * enterThreshold;
      if (distance <= threshold) {
        danger = true;
      }
    }

    if (!danger) {
      _alertAcknowledged = false;
    } else if (!state.isDanger) {
      _alertAcknowledged = false;
    }

    state = state.copyWith(
      currentPosition: position,
      isDanger: danger,
      showDangerAlert: danger && !_alertAcknowledged,
      nearestPerlintasan: nearest,
      showDangerOverlay: true,
    );

    _apiService.sendLocationUpdate(
      'masinis-001',
      position.latitude,
      position.longitude,
    );
  }

  void dismissAlert() {
    state = state.copyWith(showDangerAlert: false, showDangerOverlay: false);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
