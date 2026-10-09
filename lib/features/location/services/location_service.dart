import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/geo.dart';

/// Where the phone is, or null when that cannot be known right now.
abstract class LocationService {
  Future<LatLon?> currentPosition();
}

/// GPS through the platform. Works offline: a fix needs satellites, not data.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  @override
  Future<LatLon?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        final fix = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(timeLimit: timeout),
        );
        return LatLon(fix.latitude, fix.longitude);
      } on TimeoutException {
        // Indoors a fresh fix can take too long; a recent one is good enough
        // to pick a city and rank nearby places.
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : LatLon(last.latitude, last.longitude);
      }
    } on Exception {
      return null;
    }
  }
}
