import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/check/services/message_checker.dart';

/// The timed check on Android runs a Kotlin copy of the rules
/// (`android/app/src/main/kotlin/.../check/`). This writes down what the
/// Dart checker says about a set of messages, and `MessageRulesTest.kt`
/// requires the Kotlin copy to say the same.
///
/// After changing a rule, the pack's lists or the messages below:
///
///     UPDATE_CASES=1 flutter test test/features/check/checker_cases_test.dart
///     cd android && ./gradlew :app:testDebugUnitTest
///
/// Like the inbox replay test, this opens the built pack on the laptop.
void main() {
  final pack = File('assets/pack/metro-manila.sqlite');
  final cases = File('test/fixtures/checker_cases.json');
  final inboxFolder = Directory('pack/raw/inbox');

  /// Links, senders and wording the pack's own examples do not cover.
  const extra = [
    'GCash: I-verify ang account mo sa https://gcash-verify.com',
    'GCash: I-verify ang account mo sa https://www.gcash.com/help',
    'Mula sa DSWD: kunin ang ayuda sa dswd-ayuda.net ngayon',
    'DSWD Advisory: tingnan ang https://www.dswd.gov.ph/ayuda',
    'Your BDO account is locked. Visit bdo-online.com to restore.',
    'BDO: Your card was used. Details at https://bit.ly/3abcXYZ',
    'Paki-GCash na lang ng bayad, salamat. Tingnan mo sa shopee.ph',
    'Hi, this is from Maya. Your wallet needs to verify at maya-secure.ph',
    'maya ko pa babayaran, tingnan mo muna sa lazada.com.ph',
    'Smart: Your postpaid bill is ready. Pay at https://smart.com.ph/pay',
    'Smart ka talaga! Check mo to: tinyurl.com/abc123',
    'Para sa refund, pumunta sa csraftersales. com at pakitanggal ang space',
    'Customer service: visit helpdesk-refund (dot) com for your claim',
    'I-type ang supportcenter .com (alisin ang space) para makuha',
    'Kita tayo sa Oct.20, sabi ni Hi.Ako daw bahala',
    'Meralco Advisory: Bayaran ang bill sa http://meralco-bills.xyz/pay?id=1',
    'Follow us at https://facebook.com/gcashofficial. GCash: salamat!',
    'PLDT: Ang iyong account ay may balanse. https://pldthome.com/bills',
    'Congrats! Claim your 100% welcome bonus, free spins at cashback sa '
        'https://lucky-casino88.com',
    'BingoPlus: Deposit now, get rebate and free bonus! bingoplus.com',
    'Sali na sa jackpot! Mag-deposit at kunin ang rebate: https://bit.ly/win',
    'Globe: Your rewards points expire soon. Redeem in the app.',
    'Agent ng BPI ito. Ibigay ang OTP para ma-verify ang account mo.',
    'Landbank: I-update ang account mo sa landbank-verify.com.ph',
    'From the SSS team: update your record at https://sss.gov.ph',
    'Padala mo sa 09171234567 via Palawan Express, salamat',
    'GCash: I-verify ang account mo sa https://secure-wallet-login.com',
    'Mula sa DSWD, kunin ang ayuda dito: ayuda-claim-ph.net/form',
    'Your BPI account mo ay naka-hold. Buksan ang https://account-restore.info',
    'GCash: sundan kami sa https://www.youtube.com/watch?v=abc',
    'Your account is restricted. Open https://account-restore.info now.',
    'Your OTP is 123456. Do not share it with anyone.',
  ];

  const senders = [
    null,
    '09171234567',
    '+63 917 123 4567',
    'GCash',
    'BDO Alert',
    '8080',
  ];

  Future<List<Map<String, Object?>>> answers(
    MessageChecker checker,
    Iterable<(String, String?)> messages,
  ) async => [
    for (final (text, sender) in messages)
      await checker
          .check(text, sender: sender, phrasing: false)
          .then(
            (result) => {
              'text': text,
              'sender': sender,
              'verdict': result.verdict.name,
              'reasons': [
                for (final reason in result.reasons)
                  {'id': reason.id, 'facts': reason.facts},
              ],
            },
          ),
  ];

  test('the cases for the Kotlin rules are up to date', () async {
    final store = PackStore.open(pack.path);
    addTearDown(store.close);
    final officials = store.officialSenders();
    final checker = MessageChecker(
      senders: officials,
      shorteners: store.linkShorteners(),
      neutralHosts: store.neutralHosts(),
      gambling: store.gamblingRules(),
      bankSenders: store.bankSenders(),
    );
    final gambling = store.gamblingRules();
    final rules = {
      'senders': [
        for (final sender in officials)
          {
            'short': sender.short,
            'aliases': sender.aliases,
            'strict_aliases': sender.strictAliases,
            'domains': sender.domains,
          },
      ],
      'shorteners': store.linkShorteners(),
      'neutral_hosts': store.neutralHosts(),
      'bank_senders': store.bankSenders(),
      'gambling': {
        'brands': [
          for (final brand in gambling.brands)
            {
              'name': brand.name,
              'aliases': brand.aliases,
              'domains': brand.domains,
            },
        ],
        'host_words': gambling.hostWords,
        'terms': gambling.terms,
      },
    };

    List<String> texts(String path) => [
      for (final item in jsonDecode(File(path).readAsStringSync()) as List)
        (item as Map)['text'] as String,
    ];
    final messages = [
      ...texts('pack/data/scam_examples.json'),
      ...texts('pack/data/check_messages.json'),
      ...extra,
    ];
    const encoder = JsonEncoder.withIndent(' ');
    final written =
        '${encoder.convert({
          'rules': rules,
          'cases': await answers(checker, [for (final text in messages)
            for (final sender in senders) (text, sender)]),
        })}\n';

    // The private inbox gives the Kotlin copy hundreds of real texts. Its
    // case file stays in pack/raw/, which git ignores.
    final saved = inboxFolder.existsSync()
        ? (inboxFolder.listSync().whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];
    if (saved.isNotEmpty) {
      final inbox = jsonDecode(saved.last.readAsStringSync()) as Map;
      File('pack/raw/checker_cases_inbox.json').writeAsStringSync(
        jsonEncode({
          'rules': rules,
          'cases': await answers(checker, [
            for (final message in (inbox['messages'] as List).cast<Map>())
              (
                message['body'] as String,
                message['sender_kind'] == 'mobile'
                    ? '09170000000'
                    : message['sender'] as String,
              ),
          ]),
        }),
      );
    }

    if (Platform.environment['UPDATE_CASES'] == '1') {
      cases.writeAsStringSync(written);
    }
    expect(
      cases.existsSync() ? cases.readAsStringSync() : '',
      written,
      reason:
          'The rules or their lists changed. Rewrite the cases with '
          'UPDATE_CASES=1, then run the Kotlin test and bring the Kotlin '
          'copy in line.',
    );
  }, skip: pack.existsSync() ? false : 'No built pack in assets/pack/');
}
