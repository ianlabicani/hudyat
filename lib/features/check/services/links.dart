/// Top-level domains accepted for a link written without "http". Anything
/// may follow "http://"; a bare "word.word" must end in one of these, or
/// "Oct.20" and "Hi.Ako" would count as links.
const _bareTlds = {
  'com',
  'ph',
  'net',
  'org',
  'info',
  'xyz',
  'top',
  'site',
  'online',
  'cc',
  'co',
  'io',
  'me',
  'ly',
  'gd',
  'gy',
  'app',
  'link',
  'shop',
  'club',
  'vip',
  'live',
  'click',
  'biz',
  'gov',
  'id',
  'to',
  'be',
  'at',
  'ee',
  'bio',
  'store',
  'icu',
  'cn',
  'ru',
  'tk',
  'ml',
  'ga',
  'cf',
  'win',
  'work',
  'life',
  'pro',
};

final _withScheme = RegExp(r'https?://([^\s/?#]+)', caseSensitive: false);
final _bare = RegExp(
  r'(?<![\w@.])((?:[a-z0-9-]+\.)+([a-z]{2,6}))(?![\w-])',
  caseSensitive: false,
);

String _clean(String host) {
  var value = host.toLowerCase();
  final at = value.lastIndexOf('@');
  if (at >= 0) value = value.substring(at + 1);
  value = value.split(':').first;
  while (value.endsWith('.')) {
    value = value.substring(0, value.length - 1);
  }
  return value.startsWith('www.') ? value.substring(4) : value;
}

/// The host of every link in [text], lower-cased and without "www.", in
/// order of appearance and without repeats.
List<String> linkHosts(String text) {
  final found = <int, String>{};
  for (final match in _withScheme.allMatches(text)) {
    found[match.start] = _clean(match[1]!);
  }
  final taken = [
    for (final m in _withScheme.allMatches(text)) (m.start, m.end),
  ];
  for (final match in _bare.allMatches(text)) {
    final inside = taken.any((r) => match.start >= r.$1 && match.start < r.$2);
    if (inside || !_bareTlds.contains(match[2]!.toLowerCase())) continue;
    found[match.start] = _clean(match[1]!);
  }
  final ordered = found.keys.toList()..sort();
  final hosts = <String>[];
  for (final key in ordered) {
    final host = found[key]!;
    if (host.contains('.') && !hosts.contains(host)) hosts.add(host);
  }
  return hosts;
}

/// Whether [host] is [domain] itself or one of its subdomains.
bool isOnDomain(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

/// The public cannot register these, so they are always treated as official.
bool isGovernmentHost(String host) =>
    host == 'gov.ph' || host.endsWith('.gov.ph');

/// Whether [sender] is an ordinary mobile number such as 0917 123 4567 or
/// +63 917 123 4567, rather than a sender name or a short code.
bool isMobileNumber(String sender) {
  final digits = sender.replaceAll(RegExp(r'[\s().-]'), '');
  return RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(digits);
}
