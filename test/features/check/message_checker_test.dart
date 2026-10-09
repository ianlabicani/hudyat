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
      neutralHosts: store.neutralHosts(),
      gambling: store.gamblingRules(),
      bankSenders: store.bankSenders(),
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

  group('gambling', () {
    String? source(CheckResult result) => result.reasons
        .where((r) => r.id == ReasonId.gamblingPromo)
        .firstOrNull
        ?.facts['source'];

    test('a link on a listed brand domain', () async {
      final result = await checker.check(
        'Fight for the Top! Get UP TO 1.5% Rebate and compete for P100K in '
        'Super Ace Jackpot Pacquiao Ranking! bingoplus.com/channels/slot',
        sender: 'BingoPlus',
      );
      expect(result.verdict, Verdict.caution);
      expect(ids(result), [ReasonId.gamblingPromo]);
      expect(source(result), 'BingoPlus');
    });

    test('a brand name inside an unlisted domain', () async {
      final result = await checker.check('Laro na! arenaplus-ph.vip/join');
      expect(ids(result), [ReasonId.gamblingPromo]);
      expect(source(result), 'ArenaPlus');
    });

    test('a brand as the sender name, with or without a link', () async {
      final result = await checker.check(
        'PHP 789.00 Successful Released! Pwede mo i-transfer.',
        sender: '789BIngo 2',
      );
      expect(ids(result), [ReasonId.gamblingPromo]);
      expect(source(result), '789Bingo');
    });

    test('a gambling word in the link', () async {
      final result = await checker.check('Laro na dito: ph-casino88.top');
      expect(ids(result), [ReasonId.gamblingPromo]);
      expect(source(result), 'ph-casino88.top');
    });

    test('promo wording with a link of an unknown brand', () async {
      final result = await checker.check(
        'Claim na ng 18P bonos and 2.70 percent daily rebate! Enjoy our 30K '
        'top-up reward. 100% Legit. Click dito: tbwin5.com',
        sender: 'TBWin5',
      );
      expect(result.verdict, Verdict.caution);
      expect(source(result), 'tbwin5.com');
    });

    test('with a shortened link it becomes Mukhang scam', () async {
      final result = await checker.check(
        'Sali na sa Lucky Cola, may cashback araw-araw! bit.ly/3xYz',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkShortener, ReasonId.gamblingPromo]);
      expect(source(result), 'Lucky Cola');
    });

    test('ordinary promos and alerts stay clear', () async {
      const ordinary = [
        (
          'Earn up to P200 REWARDS with GCash Missions. Cash In, Buy Load, '
              'or Pay Bills to claim your rewards today. T&Cs apply.',
          'GCash',
        ),
        (
          'Yehey! Thanks for loading, ka-TM! Meron ka nang FREE 100MB '
              'pang-internet, valid for 1 day.',
          '8080',
        ),
        ('Your Play Console verification code is 123456', 'Google'),
        (
          'You have a transaction using your BDO Debit Card at Google Play '
              'for USD 25.00.',
          'BDO Alert',
        ),
        ('May cashback sa Shopee ngayon shopee.ph/sale', 'Shopee'),
        (
          'GCash: Get cashback and a rebate on your next bill. '
              'gcash.com/promos',
          'GCash',
        ),
      ];
      for (final (text, sender) in ordinary) {
        final result = await checker.check(text, sender: sender);
        expect(result.verdict, Verdict.clear, reason: text);
      }
    });

    test('a friend naming a brand without a link is not flagged', () async {
      final result = await checker.check(
        'Tara Lucky Cola mamaya, may jackpot daw',
        sender: '0917 123 4567',
      );
      expect(result.verdict, Verdict.clear);
    });

    test('an older pack without the list flags nothing', () async {
      final older = MessageChecker(senders: store.officialSenders());
      final result = await older.check('Laro na dito: ph-casino88.top');
      expect(result.verdict, Verdict.clear);
    });

    test('the reason names where the promo is from', () {
      const reason = CheckReason(ReasonId.gamblingPromo, {
        'source': 'BingoPlus',
      });
      final wording = store.scamReasons()[reason.id]!;
      expect(reason.fill(wording.tl), 'Promo ito ng online na sugal.');
      expect(reason.fill(wording.fact), 'Mula sa: BingoPlus');
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

  group('banks', () {
    test('a link under a bank sender name is a scam', () async {
      final result = await checker.check(
        'Your account is restricted. Open https://account-restore.info now.',
        sender: 'bdo alert',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkNotOfficial, ReasonId.bankLink]);
      expect(result.reasons.first.facts, {
        'org': 'BDO',
        'domain': 'account-restore.info',
        'official': 'bdo.com.ph',
      });
      expect(result.claimed?.short, 'BDO');
    });

    test('a shortened link in a text claiming a bank is a scam', () async {
      final result = await checker.check(
        'BDO: Your card was used. Details at https://bit.ly/3abcXYZ',
      );
      expect(result.verdict, Verdict.scam);
      expect(ids(result), [ReasonId.linkShortener, ReasonId.bankLink]);
    });

    test('a look-alike link names the BSP rule too', () async {
      final result = await checker.check(
        'GCash: I-verify ang account mo sa https://gcash-verify.com',
      );
      expect(ids(result), [ReasonId.linkLookalike, ReasonId.bankLink]);
    });

    test('the bank\'s own website is left alone', () async {
      final result = await checker.check(
        'Read our advisory at https://www.gcash.com/help',
        sender: 'GCash',
      );
      expect(result.verdict, Verdict.clear);
      expect(result.claimed?.short, 'GCash');
    });

    test('a link anyone uses is left alone', () async {
      final result = await checker.check(
        'Follow us at https://facebook.com/gcashofficial',
        sender: 'GCash',
      );
      expect(result.verdict, Verdict.clear);
    });

    test('a bank sender name with no link gives no reason', () async {
      final result = await checker.check(
        'Your OTP is 123456. Do not share it.',
        sender: 'BDO',
      );
      expect(result.verdict, Verdict.clear);
    });

    test('an organisation that is not a bank keeps the old rules', () async {
      final named = await checker.check(
        'Your bill is ready: bit.ly/3xYz',
        sender: 'Smart',
      );
      expect(ids(named), [ReasonId.linkShortener]);
      expect(named.claimed, isNull);

      final claimed = await checker.check(
        'Mula sa DSWD: basahin sa bit.ly/3xYz',
      );
      expect(claimed.verdict, Verdict.caution);
      expect(ids(claimed), [ReasonId.linkShortener]);
    });

    test('an older pack without the list keeps the old rules', () async {
      final older = MessageChecker(
        senders: store.officialSenders(),
        shorteners: store.linkShorteners(),
      );
      final result = await older.check(
        'BDO: Your card was used. Details at https://bit.ly/3abcXYZ',
        sender: 'BDO',
      );
      expect(ids(result), [ReasonId.linkShortener]);
    });

    test('the reason cites the BSP memorandum', () {
      final wording = store.scamReasons()[ReasonId.bankLink]!;
      expect(wording.fact, 'Batayan: BSP Memorandum M-2022-015');
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

  group('a link broken up to get past filters', () {
    // The two wordings found 32 times in a real inbox, from mobile numbers.
    const fakeSupport =
        'Hello, Ka-Smart Communications! Kung may concern po kayo sa internet '
        'o billing, visit our website:  csraftersales. com  Pakitanggal ang '
        'space bago ang com kapag ita-type.';

    test('is read as a link and is Mukhang scam on its own', () async {
      final result = await checker.check(fakeSupport, sender: '09170000000');
      expect(result.verdict, Verdict.scam);
      expect(ids(result), contains(ReasonId.linkHidden));
      expect(
        result.reasons.firstWhere((r) => r.id == ReasonId.linkHidden).facts,
        {'domain': 'csraftersales.com'},
      );
      // Not a claim, but the organisation it names is the contact to show.
      expect(result.claimed?.short, 'Smart');
    });

    test('reads the other ways of hiding the dot', () {
      expect(brokenLinkHosts('punta sa aftersalescsr. com po'), [
        'aftersalescsr.com',
      ]);
      expect(brokenLinkHosts('visit claimnow(dot)xyz today'), ['claimnow.xyz']);
      expect(brokenLinkHosts('open claimnow dot com now'), ['claimnow.com']);
      expect(brokenLinkHosts('type promo-site .com, remove the space'), [
        'promo-site.com',
      ]);
    });

    test('a typo or a new sentence is not a hidden link', () {
      // A real bank promo wrote its link this way.
      expect(brokenLinkHosts('Book via agoda .com/bdotraveldeals'), isEmpty);
      expect(brokenLinkHosts('Buksan ang app. Net pay mo ay P500.'), isEmpty);
      expect(
        brokenLinkHosts('More fun and entertainment.\nTop up now'),
        isEmpty,
      );
      expect(brokenLinkHosts('Salamat po. Com lab tayo bukas.'), isEmpty);
    });

    test('an official domain written that way is left alone', () async {
      final result = await checker.check('Details at gcash. com/help');
      expect(result.verdict, Verdict.clear);
    });
  });

  group('real company texts stay clear', () {
    test(
      'a link to the company\'s Facebook page is not "not theirs"',
      () async {
        final result = await checker.check(
          'GCash: For concerns, message us at facebook.com/gcashofficial.',
          sender: 'GCash',
        );
        expect(result.verdict, Verdict.clear);
      },
    );

    test('promo and notice wording from sender names', () async {
      for (final (sender, text) in [
        ('GCash', 'You have received PHP 500.00 of GCash from JU** D.'),
        ('BDO Alert', 'BDO: Your OTP is ######. Never share it with anyone.'),
        ('SSS OTP', 'Your My.SSS one-time PIN is ######.'),
        ('Smart', 'Smart: You have 2GB left on your promo until tomorrow.'),
      ]) {
        final result = await checker.check(text, sender: sender);
        expect(result.verdict, Verdict.clear, reason: text);
      }
    });
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
