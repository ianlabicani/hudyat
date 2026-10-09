import '../../../core/geo.dart';
import '../../../core/pack/first_aid_card.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/pack/pack_store.dart';
import '../../location/state/location_controller.dart';
import '../models/help_card.dart';

/// Turns an intent and a location into a [HelpCard]. No model is involved:
/// everything comes from the pack.
class Resolver {
  Resolver(this._store);

  final PackStore _store;

  /// Places shown when distances are known, and when they are not.
  static const nearestCount = 5;
  static const cityListCount = 8;

  /// Offices that answer emergency calls directly go first.
  static final _urgentName = RegExp(
    r'emergency|rescue|ambulance|command|drrm|\b911\b',
    caseSensitive: false,
  );

  HelpCard resolve({
    required IntentDef intent,
    required String city,
    required CitySource citySource,
    LatLon? position,
    FirstAidCard? firstAid,
  }) {
    final categories = intent.hotlineCategories;
    final province = _store.provinceOf(city);

    var level = HotlineLevel.city;
    String? levelName = city;
    var hotlines = _callable(
      _store.hotlines(categories: categories, city: city),
    );
    if (hotlines.isEmpty && province != null) {
      level = HotlineLevel.province;
      levelName = province;
      hotlines = _callable(
        _store.hotlines(categories: categories, province: province),
      );
    }
    if (hotlines.isEmpty) {
      level = HotlineLevel.national;
      levelName = null;
      hotlines = _callable(_store.hotlines(categories: categories));
    }
    _rank(hotlines, categories);

    return HelpCard(
      intent: intent,
      city: city,
      citySource: citySource,
      hotlines: hotlines,
      hotlineLevel: level,
      hotlineLevelName: levelName,
      nationalEmergency: level == HotlineLevel.national
          ? null
          : _store.nationalEmergency(),
      places: _places(intent.placeKinds, city, position),
      buildDate: _store.meta.buildDate,
      firstAid: firstAid,
    );
  }

  /// A hotline nobody can dial does not belong on an emergency card.
  List<PackRecord> _callable(List<PackRecord> rows) => [
    for (final row in rows)
      if (row.canCall) row,
  ];

  void _rank(List<PackRecord> rows, List<String> categories) {
    int score(PackRecord row) {
      final urgent = _urgentName.hasMatch(row.name) ? 0 : 100;
      final order = categories.indexOf(row.category);
      return urgent + (order < 0 ? categories.length : order);
    }

    // The sort is stable on id, so pack order breaks ties.
    rows.sort((a, b) {
      final byScore = score(a).compareTo(score(b));
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });
  }

  List<PlaceHit> _places(List<String> kinds, String city, LatLon? position) {
    if (kinds.isEmpty) return const [];
    if (position == null) {
      return [
        for (final place
            in _store.places(kinds: kinds, city: city).take(cityListCount))
          PlaceHit(place, null),
      ];
    }
    final hits = [
      for (final place in _store.places(kinds: kinds))
        PlaceHit(place, PackStore.distanceTo(place, position)),
    ]..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return hits.take(nearestCount).toList();
  }
}
