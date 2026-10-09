import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/models/flagged_sender.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';

void main() {
  var nextId = 0;

  /// A kept message; a higher [minute] is newer.
  FlaggedMessage kept(
    Verdict verdict, {
    String? sender,
    String? app,
    int minute = 0,
    bool promo = false,
  }) {
    nextId++;
    return FlaggedMessage(
      id: nextId,
      checkedAt: DateTime(2026, 10, 9, 20, minute),
      result: CheckResult(
        text: 'text $nextId',
        verdict: verdict,
        reasons: [
          CheckReason(promo ? ReasonId.gamblingPromo : ReasonId.linkShortener),
        ],
        phrasing: PhrasingState.skipped,
        sender: sender,
        app: app,
      ),
    );
  }

  /// Newest first, as `FlaggedStore.all` returns them.
  List<FlaggedMessage> newestFirst(List<FlaggedMessage> items) =>
      [...items]..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));

  test('nothing kept gives no senders', () {
    expect(groupBySender(const []), isEmpty);
  });

  test('one group per sender, with counts per kind', () {
    final groups = groupBySender(
      newestFirst([
        kept(Verdict.scam, sender: 'GCASH', minute: 1),
        kept(Verdict.caution, sender: 'GCASH', minute: 2),
        kept(Verdict.caution, sender: 'BingoPlus', minute: 3, promo: true),
        kept(Verdict.scam, sender: 'GCASH', minute: 4),
      ]),
    );
    expect(groups, hasLength(2));
    final gcash = groups.firstWhere((group) => group.sender == 'GCASH');
    expect(gcash.messages, hasLength(3));
    expect(gcash.scam, hasLength(2));
    expect(gcash.caution, hasLength(1));
    expect(gcash.promo, isEmpty);
    expect(gcash.worst, Verdict.scam);
    expect(gcash.counts, '2 Mukhang scam · 1 Mag-ingat');
    expect(gcash.latest.checkedAt.minute, 4);

    final bingo = groups.firstWhere((group) => group.sender == 'BingoPlus');
    expect(bingo.worst, Verdict.caution);
    expect(bingo.counts, '1 Sugal promo');
  });

  test('senders with a scam come first, then the newest', () {
    final groups = groupBySender(
      newestFirst([
        kept(Verdict.scam, sender: 'OLD-SCAM', minute: 1),
        kept(Verdict.caution, sender: 'OLD-CAUTION', minute: 2),
        kept(Verdict.scam, sender: 'NEW-SCAM', minute: 3),
        kept(Verdict.caution, sender: 'NEW-CAUTION', minute: 4),
      ]),
    );
    expect(
      [for (final group in groups) group.sender],
      ['NEW-SCAM', 'OLD-SCAM', 'NEW-CAUTION', 'OLD-CAUTION'],
    );
  });

  test('texts with no sender share one group', () {
    final groups = groupBySender(
      newestFirst([
        kept(Verdict.caution, minute: 1),
        kept(Verdict.caution, minute: 2),
      ]),
    );
    expect(groups, hasLength(1));
    expect(groups.single.sender, isNull);
    expect(groups.single.title, 'Sender not given');
    expect(groups.single.messages, hasLength(2));
  });

  test('the same name from another app is another sender', () {
    final groups = groupBySender(
      newestFirst([
        kept(Verdict.caution, sender: 'Juan', minute: 1),
        kept(Verdict.caution, sender: 'Juan', app: 'Messenger', minute: 2),
      ]),
    );
    expect(groups, hasLength(2));
    expect(groups.first.title, 'Juan · via Messenger');
    expect(groups.last.title, 'Juan');
  });

  test('senderGroup finds one sender, or nothing once it is empty', () {
    final all = newestFirst([
      kept(Verdict.scam, sender: 'GCASH', minute: 1),
      kept(Verdict.caution, minute: 2),
    ]);
    expect(senderGroup(all, sender: 'GCASH')!.messages, hasLength(1));
    expect(senderGroup(all)!.title, 'Sender not given');
    expect(senderGroup(all, sender: 'BDO'), isNull);
    expect(senderGroup(all, sender: 'GCASH', app: 'Viber'), isNull);
  });
}
