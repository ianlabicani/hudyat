import '../services/flagged_store.dart';
import 'check_result.dart';

/// The kept messages from one sender, as one row of the Flagged list.
class FlaggedSender {
  const FlaggedSender({
    required this.messages,
    required this.sender,
    required this.app,
  });

  /// Null for texts kept without a sender, such as pasted ones.
  final String? sender;

  /// The app the notifications came from; null for SMS, paste and share.
  final String? app;

  /// Newest first, never empty.
  final List<FlaggedMessage> messages;

  String get title => [
    sender ?? 'Sender not given',
    if (app case final app?) 'via $app',
  ].join(' · ');

  FlaggedMessage get latest => messages.first;

  List<FlaggedMessage> get scam => [
    for (final item in messages)
      if (item.result.verdict == Verdict.scam) item,
  ];

  List<FlaggedMessage> get caution => [
    for (final item in messages)
      if (item.result.verdict == Verdict.caution &&
          !item.result.isGamblingPromo)
        item,
  ];

  /// Promos and nothing else, as on the widget's third count.
  List<FlaggedMessage> get promo => [
    for (final item in messages)
      if (item.result.verdict == Verdict.caution && item.result.isGamblingPromo)
        item,
  ];

  Verdict get worst => scam.isEmpty ? Verdict.caution : Verdict.scam;

  /// How many of each kind, leaving out the kinds with none.
  String get counts => [
    if (scam.isNotEmpty) '${scam.length} ${Verdict.scam.label}',
    if (caution.isNotEmpty) '${caution.length} ${Verdict.caution.label}',
    if (promo.isNotEmpty) '${promo.length} $promoLabel',
  ].join(' · ');

  static const promoLabel = 'Sugal promo';
}

/// [all] grouped by sender and app. Senders with a "Mukhang scam" text come
/// first, then the sender with the newest text. [all] must be newest first,
/// as [FlaggedStore.all] returns it.
List<FlaggedSender> groupBySender(List<FlaggedMessage> all) {
  final bySender = <(String?, String?), List<FlaggedMessage>>{};
  for (final item in all) {
    bySender
        .putIfAbsent((item.result.sender, item.result.app), () => [])
        .add(item);
  }
  final groups = [
    for (final MapEntry(key: (sender, app), value: messages)
        in bySender.entries)
      FlaggedSender(sender: sender, app: app, messages: messages),
  ];
  return [
    for (final group in groups)
      if (group.worst == Verdict.scam) group,
    for (final group in groups)
      if (group.worst != Verdict.scam) group,
  ];
}

/// The group for one sender, or null when nothing from it is kept.
FlaggedSender? senderGroup(
  List<FlaggedMessage> all, {
  String? sender,
  String? app,
}) {
  final messages = [
    for (final item in all)
      if (item.result.sender == sender && item.result.app == app) item,
  ];
  return messages.isEmpty
      ? null
      : FlaggedSender(sender: sender, app: app, messages: messages);
}
