import '../../../core/pack/first_aid_card.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/pack/pack_store.dart';
import '../../location/state/location_controller.dart';

/// A place on a card. [distanceKm] is null when there is no GPS fix.
class PlaceHit {
  const PlaceHit(this.place, this.distanceKm);

  final PackRecord place;
  final double? distanceKm;
}

/// Everything the Card screen shows. Every fact here is pack data.
class HelpCard {
  const HelpCard({
    required this.intent,
    required this.city,
    required this.citySource,
    required this.hotlines,
    required this.hotlineLevel,
    required this.hotlineLevelName,
    required this.nationalEmergency,
    required this.places,
    required this.buildDate,
    this.firstAid,
  });

  /// The first-aid card the user's message matched, if any.
  final FirstAidCard? firstAid;

  final IntentDef intent;
  final String city;
  final CitySource citySource;

  /// Empty for intents with no hotline, such as finding a pharmacy.
  final List<PackRecord> hotlines;
  final HotlineLevel hotlineLevel;

  /// The city or province the hotlines belong to; null at national level.
  final String? hotlineLevelName;

  /// Shown as an extra row when the hotlines above are not national.
  final PackRecord? nationalEmergency;
  final List<PlaceHit> places;
  final String buildDate;

  bool get hasDistances => places.any((hit) => hit.distanceKm != null);

  /// Whether the user's own city had no number and a wider level is shown.
  bool get isFallback =>
      hotlines.isNotEmpty && hotlineLevel != HotlineLevel.city;
}
