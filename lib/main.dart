import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'core/app_scope.dart';
import 'core/models/edge_ai_runtime.dart';
import 'core/models/model_manager.dart';
import 'core/models/suspicious_artifact.dart';
import 'core/pack/pack_installer.dart';
import 'core/pack/pack_store.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/buttons.dart';
import 'core/widgets/panels.dart';
import 'features/card/services/resolver.dart';
import 'features/check/services/flagged_store.dart';
import 'features/check/models/check_result.dart';
import 'features/check/services/inbox_scanner.dart';
import 'features/check/services/scan_index.dart';
import 'features/check/services/protection_platform.dart';
import 'features/check/services/sms_inbox.dart';
import 'features/check/screens/check_screen.dart';
import 'features/check/screens/flagged_screen.dart';
import 'features/check/screens/result_screen.dart';
import 'features/check/services/timed_check.dart';
import 'features/check/services/message_checker.dart';
import 'features/check/services/share_entry.dart';
import 'features/home/screens/home_screen.dart';
import 'features/location/services/location_service.dart';
import 'features/location/state/location_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HudyatApp());
}

class HudyatApp extends StatefulWidget {
  const HudyatApp({super.key});

  @override
  State<HudyatApp> createState() => _HudyatAppState();
}

class _HudyatAppState extends State<HudyatApp> with WidgetsBindingObserver {
  PackStore? _store;
  LocationController? _location;
  ModelManager? _models;
  MessageChecker? _checker;
  FlaggedStore? _flagged;

  /// Where the flagged messages are kept, to read them through a second
  /// connection when the first cannot see what the phone just wrote.
  String? _flaggedPath;
  TimedCheck? _timed;
  InboxScanner? _scanner;
  ProtectionController? _protection;
  bool _foreground = true;
  Object? _error;
  String? _lastAiVersion;

  final _navigator = GlobalKey<NavigatorState>();
  final _share = ShareEntry();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Back on screen: pick up texts that arrived while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scanner?.setForeground(_foreground);
    if (_foreground) {
      unawaited(_catchUp());
      unawaited(_protection?.refresh());
      unawaited(_resumeNotificationAI());
    }
  }

  void _modelReady() {
    final version = _checker?.aiVersion;
    if (version == null) {
      _lastAiVersion = null;
      return;
    }
    if (version == _lastAiVersion && _models?.loading == true) return;
    _lastAiVersion = version;
    unawaited(_scanner?.resumeWording());
    unawaited(_resumeNotificationAI());
  }

  /// Flags new texts, then has the widget recount.
  Future<void> _catchUp() async {
    await _timed?.refresh();
    if (_timed?.status.on == true) {
      await _timed?.checkNow();
      await _scanner?.catchUp();
    }
  }

  Future<void> _resumeNotificationAI() async {
    final checker = _checker;
    final flagged = _flagged;
    final version = checker?.aiVersion;
    if (!_foreground || checker == null || flagged == null || version == null) {
      return;
    }
    final watch = Stopwatch()..start();
    for (final item in flagged.notificationFindingsAwaitingAI(version)) {
      if (!_foreground ||
          watch.elapsed >= const Duration(seconds: 30) ||
          checker.aiVersion != version) {
        break;
      }
      final old = item.result;
      final updated = await checker.check(
        old.text,
        sender: old.sender,
        app: old.app,
        truncated: old.truncated,
      );
      if (updated.phrasing != PhrasingState.checked) break;
      flagged.keep(
        updated,
        at: item.checkedAt,
        sourceKey: item.sourceKey,
        sourceType: item.sourceType,
        sourcePackage: item.sourcePackage,
        arrivedAt: item.arrivedAt,
        rulesVersion: item.rulesVersion,
        aiVersion: version,
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final store = PackStore.open(await installBundledPack());
      store.meta; // Fails here, not on first use, if the pack is unreadable.
      final support = await getApplicationSupportDirectory();
      const phoneTest =
          kDebugMode && bool.fromEnvironment('HUDYAT_CLASSIFIER_PHONE_TEST');
      SuspiciousArtifact? candidate;
      if (phoneTest) {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          final file = File(p.join(external.path, 'classifier-candidate.json'));
          if (await file.exists()) {
            try {
              candidate = SuspiciousArtifact.fromJson(
                jsonDecode(await file.readAsString()) as Map<String, dynamic>,
              );
            } on Object {
              /* Invalid trial input keeps the baseline. */
            }
          }
        }
      }
      final models = ModelManager(
        runtime: EdgeAiRuntime(),
        intents: store.intents(),
        cacheFile: File(p.join(support.path, 'intent-vectors.json')),
        scamExamples: store.scamExamples(),
        scamCacheFile: File(p.join(support.path, 'scam-vectors.json')),
        firstAidCards: store.firstAidCards(),
        firstAidCacheFile: File(p.join(support.path, 'first-aid-vectors.json')),
        suspiciousArtifact: candidate ?? store.suspiciousArtifact(),
        phoneTest: phoneTest,
      );
      final senders = store.officialSenders();
      final checker = MessageChecker(
        senders: senders,
        shorteners: store.linkShorteners(),
        neutralHosts: store.neutralHosts(),
        gambling: store.gamblingRules(),
        phrases: () => models.scamPhrases,
        classifier: () => models.suspiciousClassifier,
      );
      // Flagged messages live in their own file, apart from the pack.
      final flaggedPath = p.join(support.path, 'flagged.sqlite');
      _flaggedPath = flaggedPath;
      final kept = sqlite3.open(flaggedPath);
      final flagged = FlaggedStore(kept, senders: senders);
      final scanner = InboxScanner(
        inbox: const AndroidSmsInbox(),
        checker: checker,
        flagged: flagged,
        // In the same file, but it holds ids and verdicts, never text.
        index: ScanIndex(kept),
        rules: '${store.rulesVersion()}-$checkerVersion',
        phrases: () => models.scamPhrases,
      );
      final timed = TimedCheck(
        platform: const AndroidTimedCheck(),
        inbox: const AndroidSmsInbox(),
      );
      final protection = ProtectionController(
        const AndroidProtectionPlatform(),
        onResultsChanged: () {
          flagged.nativeResultsChanged();
          unawaited(_resumeNotificationAI());
        },
      );
      _scanner = scanner;
      scanner.setForeground(
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      _timed = timed;
      _protection = protection;
      unawaited(protection.refresh());
      models.addListener(_modelReady);
      unawaited(_catchUp());
      // Models load in the background; the app is usable before they do.
      unawaited(models.load());
      setState(() {
        _store = store;
        _location = LocationController(
          const GeolocatorLocationService(),
          store,
        );
        _models = models;
        _checker = checker;
        _flagged = flagged;
      });
      // Text shared while the app was closed, then anything shared later.
      _share.listen(_openShared);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openShared());
    } on Object catch (error) {
      setState(() => _error = error);
    }
  }

  /// Opens the Check screen with whatever another app handed over, or the
  /// Flagged list for a tap on a scam alert or the widget.
  Future<void> _openShared() async {
    final shared = await _share.take();
    if (shared == null || !mounted) return;
    final saved = shared.resultId == null
        ? null
        : _savedResult(shared.resultId!);
    unawaited(
      _navigator.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => shared.resultId != null
              ? saved == null
                    ? const _UnavailableResultScreen()
                    : ResultScreen(result: saved.result)
              : shared.openFlagged
              ? const FlaggedScreen()
              : CheckScreen(
                  initialText: shared.text,
                  sharedWithoutText: shared.text == null,
                ),
        ),
      ),
    );
  }

  /// The kept message an alert points to. The alert's row is written by the
  /// Android side through its own connection, and on the phone the app's
  /// connection has been seen to miss it, so a miss is retried on a fresh
  /// connection before the result is called unavailable.
  FlaggedMessage? _savedResult(int id) {
    final flagged = _flagged;
    final found = flagged?.byId(id);
    final path = _flaggedPath;
    if (found != null || flagged == null || path == null) return found;
    final fresh = FlaggedStore.open(
      path,
      senders: _store?.officialSenders() ?? const [],
    );
    try {
      final again = fresh.byId(id);
      debugPrint(
        'Hudyat: result $id is not on the app connection '
        '(${flagged.count} kept); a fresh connection '
        '${again == null ? 'lacks it too' : 'has it'} (${fresh.count} kept)',
      );
      return again;
    } finally {
      fresh.close();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timed?.dispose();
    _protection?.dispose();
    _scanner?.dispose();
    _share.dispose();
    _location?.dispose();
    _models?.dispose();
    _flagged?.close();
    _store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final location = _location;
    final models = _models;
    final checker = _checker;
    final flagged = _flagged;
    final timed = _timed;
    final scanner = _scanner;
    if (store == null ||
        location == null ||
        models == null ||
        checker == null ||
        flagged == null ||
        timed == null ||
        scanner == null) {
      return MaterialApp(
        title: 'Hudyat',
        theme: hudyatTheme(),
        home: _StartupScreen(error: _error, onRetry: _start),
      );
    }
    return AppScope(
      store: store,
      resolver: Resolver(store),
      location: location,
      models: models,
      checker: checker,
      flagged: flagged,
      timed: timed,
      scanner: scanner,
      protection: _protection,
      child: MaterialApp(
        title: 'Hudyat',
        navigatorKey: _navigator,
        theme: hudyatTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}

class _UnavailableResultScreen extends StatelessWidget {
  const _UnavailableResultScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: TopBar(title: 'Message check'),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This saved result is no longer available. It may have been cleared.',
            style: HudyatText.body,
            textAlign: .center,
          ),
        ),
      ),
    ),
  );
}

/// Shown for the moment it takes to unpack the data, or if that fails.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HudyatShape.gutter),
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .stretch,
            spacing: 16,
            children: error == null
                ? const [
                    Center(child: CircularProgressIndicator()),
                    Text(
                      'Getting the pack ready…',
                      textAlign: .center,
                      style: HudyatText.body,
                    ),
                  ]
                : [
                    const Text(
                      'The data pack could not be opened.',
                      style: HudyatText.section,
                    ),
                    Text('$error', style: HudyatText.data),
                    const Text(
                      'In an emergency, dial 911.',
                      style: HudyatText.bodyBold,
                    ),
                    PrimaryButton(label: 'Try again', onPressed: onRetry),
                  ],
          ),
        ),
      ),
    );
  }
}
