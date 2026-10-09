import '../../../core/pack/scam_records.dart';

/// The three fixed outcomes of a message check. There is no "safe".
enum Verdict {
  scam('Mukhang scam', 'Looks like a scam'),
  caution('Mag-ingat', 'Be careful'),
  clear('Walang nakitang problema', 'No problem found');

  const Verdict(this.label, this.gloss);

  final String label;
  final String gloss;
}

/// Ids of the pack's `scam_reasons` rows.
abstract final class ReasonId {
  static const linkLookalike = 'link_lookalike';
  static const linkNotOfficial = 'link_not_official';
  static const senderMobile = 'sender_mobile';
  static const linkShortener = 'link_shortener';
  static const phrasing = 'phrasing';
  static const linkHidden = 'link_hidden';
  static const gamblingPromo = 'gambling_promo';
  static const bankLink = 'bank_link';
  static const suspicious = {
    'ask_credentials',
    'ask_money',
    'ask_action',
    'ask_pressure',
    'ask_bait',
  };
}

/// One finding: a reason id plus the facts that fill its fixed wording.
class CheckReason {
  const CheckReason(this.id, [this.facts = const {}]);

  final String id;

  /// Values for the wording's placeholders: `org`, `domain`, `official`,
  /// `sender`, `type`, `source`.
  final Map<String, String> facts;

  /// [template] with its placeholders filled in.
  String fill(String template) => template.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (match) => facts[match[1]] ?? '',
  );
}

/// Where the phrasing check stood when the message was checked.
enum PhrasingState {
  /// A legacy saved result did not record whether AI ran.
  unknown,
  checked,
  notReady,

  /// Left out on purpose: an inbox scan runs the fast rules first.
  skipped,
}

/// Everything a check produces. No free text: a verdict, reason ids and
/// facts from the pack.
class CheckResult {
  const CheckResult({
    required this.text,
    required this.verdict,
    required this.reasons,
    required this.phrasing,
    this.sender,
    this.app,
    this.claimed,
    this.linkCount = 0,
    this.truncated = false,
  });

  final String text;
  final Verdict verdict;
  final List<CheckReason> reasons;
  final PhrasingState phrasing;

  /// Who sent it, when known. Paste, share and selection often have none.
  final String? sender;

  /// The app a notification came from.
  final String? app;

  /// The organisation the message claims to be, whose real contact is shown.
  final OfficialSender? claimed;
  final int linkCount;

  /// Read from a notification, which may cut a long message short.
  final bool truncated;

  /// Only these are ever stored.
  bool get isFlagged => verdict != Verdict.clear;

  /// Whether a gambling promo was found, whatever else was.
  bool get hasGamblingPromo =>
      reasons.any((reason) => reason.id == ReasonId.gamblingPromo);

  /// A gambling promo and nothing else: it gets its own group in the
  /// Flagged list, apart from other "Mag-ingat" texts.
  bool get isGamblingPromo => reasons.length == 1 && hasGamblingPromo;
}
