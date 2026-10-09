import '../../../core/pack/scam_records.dart';
import 'links.dart';

/// Spots online gambling promos by brand, link and wording (spec 3.4).
/// Words such as "bonus" or "play" never count on their own: telcos and
/// e-wallets use them too.
class GamblingMatcher {
  GamblingMatcher(this._rules)
    : _terms = [
        for (final term in _rules.terms)
          RegExp('(?<![a-z0-9])${RegExp.escape(term.toLowerCase())}'),
      ];

  final GamblingRules _rules;
  final List<RegExp> _terms;

  static String _squash(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Who the promo in [text] is from: the brand when it is a listed one,
  /// else the link's domain. Null when this is not a gambling promo.
  String? match(
    String text,
    List<String> hosts, {
    String? sender,
    bool Function(String host)? isOfficial,
  }) {
    final from = _squash(sender ?? '');
    final plain = text.toLowerCase().replaceAll(RegExp(r'[-\s]+'), ' ');
    final wording = _terms.where((term) => term.hasMatch(plain)).length;

    for (final brand in _rules.brands) {
      final onDomain = hosts.any(
        (host) => brand.domains.any((domain) => isOnDomain(host, domain)),
      );
      if (onDomain) return brand.name;
      for (final alias in brand.aliases) {
        // A short name could sit inside an ordinary word.
        final token = _squash(alias);
        if (token.length >= 5 &&
            (from.startsWith(token) ||
                hosts.any((host) => _squash(host).contains(token)))) {
          return brand.name;
        }
        // "PlayTime" and "GameZone" are also ordinary words, so a name in
        // the text needs a link and promo wording with it.
        if (hosts.isNotEmpty && wording > 0 && _names(alias, text)) {
          return brand.name;
        }
      }
    }

    for (final host in hosts) {
      final squashed = _squash(host);
      if (_rules.hostWords.any(squashed.contains)) return host;
    }

    if (wording < 2) return null;
    for (final host in hosts) {
      if (isOfficial == null || !isOfficial(host)) return host;
    }
    return null;
  }

  static bool _names(String alias, String text) => RegExp(
    '(?<![A-Za-z0-9])${RegExp.escape(alias)}(?![A-Za-z0-9])',
    caseSensitive: false,
  ).hasMatch(text);
}
