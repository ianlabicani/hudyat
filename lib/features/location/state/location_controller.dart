import 'package:flutter/foundation.dart';

import '../../../core/geo.dart';
import '../../../core/pack/pack_store.dart';
import '../services/location_service.dart';

/// How the current city was decided. Cards say which.
enum CitySource { gps, manual }

/// The city in use and, when it came from GPS, the position behind it.
class LocationController extends ChangeNotifier {
  LocationController(this._service, this._store);

  final LocationService _service;
  final PackStore _store;

  LatLon? _position;
  String? _city;
  CitySource? _source;
  bool _busy = false;

  /// Set only while the city comes from GPS. A manually chosen city has no
  /// position, so distances are hidden.
  LatLon? get position => _source == CitySource.gps ? _position : null;
  String? get city => _city;
  CitySource? get source => _source;
  bool get busy => _busy;

  /// Tries for a GPS fix inside the pack's area. Returns whether it got one.
  /// A fix outside the area is treated as no fix: the pack has no places
  /// there, so the user picks a city instead.
  Future<bool> refresh() async {
    _busy = true;
    notifyListeners();
    final fix = await _service.currentPosition();
    final city = fix != null && _store.meta.covers(fix.lat, fix.lon)
        ? _store.nearestCity(fix.lat, fix.lon)
        : null;
    if (city != null) {
      _position = fix;
      _city = city;
      _source = CitySource.gps;
    }
    _busy = false;
    notifyListeners();
    return city != null;
  }

  void chooseCity(String city) {
    _city = city;
    _source = CitySource.manual;
    notifyListeners();
  }
}
