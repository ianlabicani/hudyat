import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/services/links.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/scam_phrases.dart';

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late MessageChecker checker;
  ScamPhrases? phrases;

  setUp(() {
    store = fixtureStore();
    phrases = null;
    checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
      phrases: () => phrases,
    );
  });
  tearDown(() => store.close());

  List<String> ids(CheckResult result) => [
    for (final r in result.reasons) r.id,
  ];

  group('linkHosts', () {
    test('finds links with and without a scheme, without repeats', () {
      expect(
        linkHosts(
          'Go to https://www.GCash-Verify.com/login?x=1 or bit.ly/abc, '
          'then gcash-verify.com again.',
        ),
        ['gcash-verify.com', 'bit.ly'],
      );
    });

    test('does not take amounts, dates or sentences for links', () {
      expect(linkHosts('Bayad P2,340.15 sa Oct.20. Salamat.Ingat ka'), isEmpty);
      expect(linkHosts('email me at juan@gmail.com'), isEmpty);
    });
  });

  test('isMobileNumber accepts local and +63 forms only', () {
    expect(isMobileNumber('0917 123 4567'), isTrue);
    expect(isMobileNumber('+639171234567'), isTrue);
    expect(isMobileNumber('GCash'), isFalse);
    expect(isMobileNumber('2882'), isFalse);
    expect(isMobileNumber('(02) 8888-0000'), isFalse);
  });

  group('claimedSenders', () {
    List<String> claimed(String text) => [
      for (final sender in checker.claimedSenders(text)) sender.short,
    ];

    test('a message that says who it is from', () {
      expect(claimed('GCash: Na-lock ang account mo.'), ['GCash']);
      expect(claimed('Ayuda mula sa DSWD, i-claim na.'), ['DSWD']);
      expect(claimed('Your BDO online banking will be deactivated.'), ['BDO']);
      expect(claimed('Customer service po ito ng GCash.'), ['GCash']);
      expect(claimed('Ang GCash account mo ay na-hold.'), ['GCash']);
    });

    test('mentioning an organisation is not claiming to be it', () {
      expect(claimed('Paki-GCash na lang yung hati mo, P650.'), isEmpty);
      expect(claimed('Pumila ako sa SSS kanina, ang haba.'), isEmpty);
      expect(claimed('Na-hack yung GCash account ko kahapon.'), isEmpty);
    });

    test('a three-letter acronym counts only in capitals', () {
      expect(claimed('from sss with love'), isEmpty);
      expect(claimed('Notice from SSS: your loan is ready.'), ['SSS']);
    });

    test('Smart and Maya need their capital and a telltale word', () {
      expect(claimed('Smart: Your bill is ready to view.'), ['Smart']);
      expect(claimed('Your Maya wallet needs to be verified.'), ['Maya']);
      expect(claimed('Dear Maya, kumusta ka na?'), isEmpty);
      expect(claimed('your smart idea saved the account'), isEmpty);
    });

    test('lists them in the order they appear', () {
      expect(claimed('Mula sa DSWD: i-verify ang iyong GCash account dito.'), [
        'DSWD',
        'GCash',
      ]);
    });
  });

  group('links', () {
    test('a look-alike link is Mukhang scam on its own', () async {
      final result = await checker.check(
        'I-verify ang account: https://gcash-verify.com/login',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkLookalike]);
      expect(result.reasons.single.facts, {
        'org': 'GCash',
        'domain': 'gcash-verify.com',
        'official': 'gcash.com',
      });
      expect(result.claimed?.short, 'GCash');
    });

    test('a short name must stand alone in the host', () async {
      expect(ids(await checker.check('Tingnan mo bdo-online.net')), [
        ReasonId.linkLookalike,
      ]);
      expect(ids(await checker.check('Tingnan mo abdomen.com')), isEmpty);
    });

    test('an organisation named with a link that is not theirs', () async {
      final result = await checker.check(
        'DSWD: Kunin ang ayuda mo sa http://tulong-pinoy.xyz/claim',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkNotOfficial]);
      expect(result.reasons.single.facts['official'], 'dswd.gov.ph');
    });

    test('official and government links give no reason', () async {
      for (final text in [
        'GCash: Read our advisory at https://help.gcash.com/hc',
        'DSWD: Details at https://www.dswd.gov.ph/ayuda',
        'From SSS: see https://ndrrmc.gov.ph for the list.',
      ]) {
        final result = await checker.check(text);
        expect(result.verdict, Verdict.clear, reason: text);
      }
    });

    test(
      'an ordinary link with no organisation named is not flagged',
      () async {
        final result = await checker.check(
          'Uy basahin mo to https://balita-ngayon.com/bagyo, mura rin sa GCash',
        );
        expect(result.verdict, Verdict.clear);
        expect(result.linkCount, 1);
      },
    );

    test('a shortened link alone is Mag-ingat', () async {
      final result = await checker.check('Tingnan mo to bit.ly/3xYz');
      expect(result.verdict, Verdict.caution);
      expect(ids(result), [ReasonId.linkShortener]);
    });
  });

  group('sender', () {
    const text = 'GCash: Na-hold ang iyong wallet. Tumawag sa amin.';

    test('claims an organisation from an ordinary mobile number', () async {
      final result = await checker.check(text, sender: '0917 123 4567');
      expect(result.verdict, Verdict.caution);
      expect(ids(result), [ReasonId.senderMobile]);
      expect(result.reasons.single.facts['sender'], '0917 123 4567');
    });

    test('a sender name gives no reason either way', () async {
      expect(
        (await checker.check(text, sender: 'GCash')).verdict,
        Verdict.clear,
      );
    });

    test('no sender given skips the check', () async {
      final result = await checker.check(text, sender: '  ');
      expect(result.verdict, Verdict.clear);
      expect(result.sender, isNull);
    });

    test('a friend who mentions GCash from a mobile is not flagged', () async {
      final result = await checker.check(
        'Paki-GCash na lang yung hati mo sa kuryente.',
        sender: '09171234567',
      );
      expect(result.verdict, Verdict.clear);
    });
  });

  group('phrasing', () {
    setUp(() async {
      phrases = ScamPhrases(
        embedder: FakeEmbedder(),
        examples: store.scamExamples(),
        threshold: 0.6,
      );
      await phrases!.prepare();
    });

    test('alone it is never more than Mag-ingat', () async {
      final result = await checker.check('Na-lock ang wallet, i-verify na');
      expect(result.verdict, Verdict.caution);
      expect(ids(result), [ReasonId.phrasing]);
      expect(result.reasons.single.facts['type'], 'Na-lock na account');
      expect(result.phrasing, PhrasingState.checked);
    });

    test('with a second reason it becomes Mukhang scam', () async {
      final result = await checker.check(
        'May ayuda ka, i-claim sa bit.ly/ayuda2026',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkShortener, ReasonId.phrasing]);
    });

    test('an ordinary message stays clear', () async {
      final result = await checker.check('Ma, pauwi na ako. Anong ulam?');
      expect(result.verdict, Verdict.clear);
      expect(result.isFlagged, isFalse);
    });
  });

  test('says so when the scam phrases are not ready yet', () async {
    final result = await checker.check('Na-lock ang wallet, i-verify na');
    expect(result.phrasing, PhrasingState.notReady);
    expect(result.verdict, Verdict.clear);
  });

  test('verdictFor follows the table', () {
    CheckReason r(String id) => CheckReason(id);
    expect(MessageChecker.verdictFor([]), Verdict.clear);
    expect(MessageChecker.verdictFor([r(ReasonId.phrasing)]), Verdict.caution);
    expect(
      MessageChecker.verdictFor([r(ReasonId.senderMobile)]),
      Verdict.caution,
    );
    expect(
      MessageChecker.verdictFor([r(ReasonId.linkLookalike)]),
      Verdict.scam,
    );
    expect(
      MessageChecker.verdictFor([r(ReasonId.linkNotOfficial)]),
      Verdict.scam,
    );
    expect(
      MessageChecker.verdictFor([
        r(ReasonId.senderMobile),
        r(ReasonId.phrasing),
      ]),
      Verdict.scam,
    );
  });

  test('reason wording comes from the pack, filled with the facts', () {
    final texts = store.scamReasons();
    const reason = CheckReason(ReasonId.senderMobile, {
      'org': 'GCash',
      'sender': '0917 123 4567',
    });
    final wording = texts[reason.id]!;
    expect(
      reason.fill(wording.tl),
      'Nagpapakilalang GCash pero galing sa mobile number.',
    );
    expect(reason.fill(wording.fact), 'Galing sa: 0917 123 4567');
  });

  test('carries the notification details through', () async {
    final result = await checker.check(
      'GCash: Na-hold ang wallet',
      sender: '+639171234567',
      app: 'Messages',
      truncated: true,
    );
    expect(result.app, 'Messages');
    expect(result.truncated, isTrue);
    expect(result.claimed?.dialable.first.dial, '0272139999');
  });
}
