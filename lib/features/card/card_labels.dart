import 'package:flutter/material.dart';

/// Wording and icons for the fixed intents and place kinds. Intent ids and
/// place kinds come from the pack; the text shown for them is decided here.
abstract final class CardLabels {
  /// The eight quick buttons on Home, in display order.
  static const quickIntents = [
    'medical_emergency',
    'injury',
    'fire',
    'flood_rescue',
    'crime_police',
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

  /// Short label for a quick button.
  static String quickLabel(String intentId, String fallback) =>
      switch (intentId) {
        'medical_emergency' => 'Medical',
        _ => fallback,
      };

  /// Section title and Filipino gloss for a list of places of one kind.
  static ({String plural, String gloss}) places(String kind) => switch (kind) {
    'hospital' => (plural: 'hospitals', gloss: 'ospital'),
    'clinic' => (plural: 'clinics', gloss: 'klinika'),
    'pharmacy' => (plural: 'pharmacies', gloss: 'botika'),
    'police' => (plural: 'police stations', gloss: 'istasyon ng pulis'),
    'fire_station' => (plural: 'fire stations', gloss: 'istasyon ng bumbero'),
    'shelter' => (plural: 'shelters', gloss: 'evacuation center'),
    _ => (plural: 'places', gloss: 'lugar'),
  };
}
