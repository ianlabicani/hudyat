import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Wording and icons for the fixed intents and place kinds. Intent ids and
/// place kinds come from the pack; the text shown for them is decided here.
abstract final class CardLabels {
  /// The quick buttons on Home, in display order: what a typhoon night
  /// needs in one tap.
  static const quickIntents = [
    'flood_rescue',
    'medical_emergency',
    'fire',
    'crime_police',
  ];

  /// Cards normally reached by typing. They get buttons too while the
  /// language model is missing, since typing then only searches.
  static const typedIntents = [
    'injury',
    'need_medicine',
    'need_clinic',
    'shelter',
  ];

  static IconData icon(String intentId) => switch (intentId) {
    'medical_emergency' => Icons.local_hospital_outlined,
    'injury' => Icons.healing_outlined,
    'fire' => Icons.local_fire_department_outlined,
    'flood_rescue' => Icons.flood_outlined,
    'crime_police' => Icons.local_police_outlined,
    'need_medicine' => Icons.medication_outlined,
    'need_clinic' => Icons.medical_services_outlined,
    'shelter' => Icons.night_shelter_outlined,
    _ => Icons.help_outline,
  };

  /// The icon's colour, so the kinds of help differ by more than shape.
  static Color iconColor(String intentId) => switch (intentId) {
    'flood_rescue' => HudyatColors.water,
    'medical_emergency' || 'injury' => HudyatColors.danger,
    'fire' => HudyatColors.fire,
    'crime_police' => HudyatColors.police,
    'need_medicine' || 'need_clinic' => HudyatColors.care,
    'shelter' => HudyatColors.shelter,
    _ => HudyatColors.ink,
  };

  /// Short label for a quick button.
  static String quickLabel(String intentId, String fallback) =>
      switch (intentId) {
        'medical_emergency' => 'Medical',
        _ => fallback,
      };

  /// The plural used in the heading over a list of places of one kind.
  static String places(String kind) => switch (kind) {
    'hospital' => 'hospitals',
    'clinic' => 'clinics',
    'pharmacy' => 'pharmacies',
    'police' => 'police stations',
    'fire_station' => 'fire stations',
    'shelter' => 'shelters',
    _ => 'places',
  };
}
