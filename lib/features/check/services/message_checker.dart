import '../../../core/pack/scam_records.dart';
import '../models/check_result.dart';
import 'gambling.dart';
import 'links.dart';
import 'scam_phrases.dart';
import 'suspicious_classifier.dart';

/// Raise this when the rules in [MessageChecker] change, so texts an inbox
/// scan checked with the old rules are checked again.
const checkerVersion = 4;

/// Stage 1 of the message check (spec 3.4): links, claimed sender, the
/// BSP's no-links rule for banks, gambling promos and phrasing, giving a verdict and reason ids. One checker serves paste,
/// share, selection and notifications.
class MessageChecker {
  MessageChecker({
    required this._senders,
    List<String> shorteners = const [],
    List<String> neutralHosts = const [],
    GamblingRules gambling = GamblingRules.none,
    Map<String, List<String>> bankSenders = const {},
    this.phrases,
    this.classifier,
  }) : _shorteners = shorteners.toSet(),
       _neutral = neutralHosts.toSet(),
       _gambling = GamblingMatcher(gambling),
       _banks = bankSenders.keys.toSet(),
       _bankBySender = {
         for (final bank in _senders)
           for (final name in bankSenders[bank.short] ?? const <String>[])
             name.toLowerCase(): bank,
       };

  final List<OfficialSender> _senders;

  /// Short names of banks and e-wallets, which the BSP tells not to text
  /// links.
  final Set<String> _banks;

  /// The bank a sender name belongs to, by the name in lower case. A text
  /// under that name claims to be the bank, whatever it says.
  final Map<String, OfficialSender> _bankBySender;
  final Set<String> _shorteners;

  /// Hosts anyone links to, such as a Facebook page.
  final Set<String> _neutral;
  final GamblingMatcher _gambling;

  /// Returns the phrasing check once its examples are embedded, else null.
  final ScamPhrases? Function()? phrases;
  final SuspiciousClassifier? Function()? classifier;

  String? get aiVersion =>
      classifier?.call()?.version ??
      (phrases?.call()?.isReady == true ? phrases!.call()!.version : null);
  bool get canCheckWording => aiVersion != null;

  /// Words that turn "Smart" or "Maya" from an ordinary word into a company.
  static final _telltale = RegExp(
    r'\b(account|wallet|load|sim|promo|postpaid|prepaid|subscriber|bill|'
    r'data|points|rewards|app|verify|otp)\b',
    caseSensitive: false,
  );

  Future<CheckResult> check(
    String text, {
    String? sender,
    String? app,
    bool truncated = false,
    bool phrasing = true,
  }) async {
    final from = sender?.trim();
    final broken = brokenLinkHosts(text);
    final hosts = [
      ...linkHosts(text),
      for (final host in broken)
        if (!linkHosts(text).contains(host)) host,
    ];
    final named = from == null ? null : _bankBySender[from.toLowerCase()];
    final claimed = [
      ?named,
      for (final sender in claimedSenders(text))
        if (sender != named) sender,
    ];
    final reasons = <CheckReason>[];

    void add(CheckReason reason) {
      if (!reasons.any((r) => r.id == reason.id)) reasons.add(reason);
    }

    OfficialSender? imitated;
    for (final host in hosts) {
      if (_isOfficial(host)) continue;
      if (broken.contains(host)) {
        add(CheckReason(ReasonId.linkHidden, {'domain': host}));
      }
      final copied = _imitatedBy(host, text);
      if (copied != null) {
        imitated ??= copied;
        add(
          CheckReason(ReasonId.linkLookalike, {
            'org': copied.short,
            'domain': host,
            'official': copied.domains.first,
          }),
        );
      } else if (_isShortener(host)) {
        add(CheckReason(ReasonId.linkShortener, {'domain': host}));
      } else if (claimed.isNotEmpty &&
          !_neutral.any((domain) => isOnDomain(host, domain))) {
        final org = claimed.first;
        add(
          CheckReason(ReasonId.linkNotOfficial, {
            'org': org.short,
            'domain': host,
            'official': org.domains.first,
          }),
        );
      }
      if (claimed.isNotEmpty &&
          _banks.contains(claimed.first.short) &&
          !_neutral.any((domain) => isOnDomain(host, domain))) {
        add(CheckReason(ReasonId.bankLink, {'org': claimed.first.short}));
      }
    }
    // A look-alike already says the link is not theirs.
    if (reasons.any((r) => r.id == ReasonId.linkLookalike)) {
      reasons.removeWhere((r) => r.id == ReasonId.linkNotOfficial);
    }

    if (from != null && claimed.isNotEmpty && isMobileNumber(from)) {
      add(
        CheckReason(ReasonId.senderMobile, {
          'org': claimed.first.short,
          'sender': from,
        }),
      );
    }

    final promo = _gambling.match(
      text,
      hosts,
      sender: from,
      isOfficial: _isOfficial,
    );
    if (promo != null) {
      add(CheckReason(ReasonId.gamblingPromo, {'source': promo}));
    }

    // The wording check costs about a second on a phone, so an inbox scan
    // can leave it out.
    var wordingState = phrasing
        ? PhrasingState.notReady
        : PhrasingState.skipped;
    if (phrasing) {
      try {
        final detector = classifier?.call();
        final wording = phrases?.call();
        if (detector != null) {
          for (final label in await detector.classify(text)) {
            add(CheckReason('ask_${label.name}'));
          }
          wordingState = PhrasingState.checked;
        } else if (wording != null && wording.isReady) {
          final type = await wording.match(text);
          if (type != null) add(CheckReason(ReasonId.phrasing, {'type': type}));
          wordingState = PhrasingState.checked;
        }
      } on Object {
        // Keep the rules result. A failed AI pass remains pending in the index.
      }
    }

    return CheckResult(
      text: text,
      verdict: verdictFor(reasons),
      reasons: reasons,
      phrasing: wordingState,
      sender: from == null || from.isEmpty ? null : from,
      app: app,
      claimed: claimed.isNotEmpty
          ? claimed.first
          : imitated ?? (broken.isEmpty ? null : _firstMentioned(text)),
      linkCount: hosts.length,
      truncated: truncated,
    );
  }

  /// A hard link finding, or any two findings, is "Mukhang scam". One soft
  /// finding is "Mag-ingat". Phrasing alone is never more than that.
  static Verdict verdictFor(List<CheckReason> reasons) {
    final ids = {for (final reason in reasons) reason.id};
    final groups = {
      for (final id in ids)
        if (ReasonId.suspicious.contains(id) || id == ReasonId.phrasing)
          'ai'
        else
          id,
    };
    if (ids.isEmpty) return Verdict.clear;
    if (ids.contains(ReasonId.linkLookalike) ||
        ids.contains(ReasonId.linkHidden) ||
        ids.contains(ReasonId.linkNotOfficial) ||
        groups.length >= 2) {
      return Verdict.scam;
    }
    return Verdict.caution;
  }

  /// Organisations [text] claims to come from, in the order they appear.
  /// Mentioning one is not enough: "paki-GCash na lang" names GCash without
  /// pretending to be it.
  List<OfficialSender> claimedSenders(String text) {
    final found = <(int, OfficialSender)>[];
    for (final sender in _senders) {
      final at = _claimPosition(sender, text);
      if (at != null) found.add((at, sender));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final item in found) item.$2];
  }

  /// The organisation named earliest in [text], claimed or not. Used for
  /// the contact when a hidden link shows the message is not from them.
  OfficialSender? _firstMentioned(String text) {
    OfficialSender? first;
    var at = text.length;
    for (final sender in _senders) {
      for (final match in _mentions(sender, text)) {
        if (match.start < at) {
          at = match.start;
          first = sender;
        }
      }
    }
    return first;
  }

  int? _claimPosition(OfficialSender sender, String text) {
    int? best;
    for (final match in _mentions(sender, text)) {
      if (_isClaim(text, match.start, match.end) &&
          (best == null || match.start < best)) {
        best = match.start;
      }
    }
    return best;
  }

  /// Every place [sender] is named in [text].
  Iterable<Match> _mentions(OfficialSender sender, String text) sync* {
    for (final alias in sender.aliases) {
      // A three-letter acronym in lower case is usually just a word.
      final exact = alias.length <= 3 && alias == alias.toUpperCase();
      yield* _word(alias, caseSensitive: exact).allMatches(text);
    }
    if (sender.strictAliases.isEmpty || !_telltale.hasMatch(text)) return;
    for (final alias in sender.strictAliases) {
      yield* _word(alias, caseSensitive: true).allMatches(text);
      if (alias != alias.toUpperCase()) {
        yield* _word(alias.toUpperCase(), caseSensitive: true).allMatches(text);
      }
    }
  }

  static RegExp _word(String alias, {required bool caseSensitive}) => RegExp(
    '(?<![A-Za-z0-9])${RegExp.escape(alias)}(?![A-Za-z0-9])',
    caseSensitive: caseSensitive,
  );

  static final _lead = RegExp(
    r'(^|[\n.!?]\s*)(from\s+|dear\s+|mula\s+sa\s+|galing\s+sa\s+)?$',
    caseSensitive: false,
  );
  static final _label = RegExp(
    r'^\s*([:\-–|]|advisory|alert|notice|update|reminder|ph\b|customer|'
    r'support|security|team|cash assistance)',
    caseSensitive: false,
  );
  static final _before = RegExp(
    r'(\bfrom\s+(the\s+)?|\bmula\s+sa\s+|\bgaling\s+sa\s+|\btaga[- ]|'
    r'\b(your|iyong|inyong)\s+|'
    r'\b(agent|service|support|staff|team|representative|opisina|tanggapan)'
    r'\b[^.!?\n]{0,20}\b(ng|of)\s+)$',
    caseSensitive: false,
  );
  static final _after = RegExp(
    r'^\s+(account|wallet|sim|card|number|loan)\s+(mo|ninyo|niyo|nyo|ay)\b',
    caseSensitive: false,
  );

  /// Whether the name at [start]..[end] is the message saying who it is
  /// from: "GCash: ...", "mula sa DSWD", "your BDO account", "agent ng BPI".
  bool _isClaim(String text, int start, int end) {
    final before = text.substring(0, start);
    final after = text.substring(end);
    if (_lead.hasMatch(before) && _label.hasMatch(after)) return true;
    if (_before.hasMatch(before)) return true;
    return _after.hasMatch(after);
  }

  bool _isShortener(String host) =>
      _shorteners.any((domain) => isOnDomain(host, domain));

  bool _isOfficial(String host) =>
      isGovernmentHost(host) ||
      _senders.any((s) => s.domains.any((d) => isOnDomain(host, d)));

  /// The organisation whose name [host] carries without being its site, as
  /// in "gcash-verify.com" or "dswd-ayuda.net".
  OfficialSender? _imitatedBy(String host, String text) {
    final parts = host.split(RegExp(r'[.\-_]'));
    final squashed = host.replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final sender in _senders) {
      for (final alias in sender.aliases) {
        final token = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (token.length < 3) continue;
        // Short names must stand alone ("bdo-online.com"); a long one is
        // unmistakable anywhere in the host.
        if (token.length >= 5
            ? squashed.contains(token)
            : parts.contains(token)) {
          return sender;
        }
      }
      if (_mentions(sender, text).isEmpty) continue;
      for (final alias in sender.strictAliases) {
        if (parts.contains(alias.toLowerCase())) return sender;
      }
    }
    return null;
  }
}
