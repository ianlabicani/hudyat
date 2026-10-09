import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'core/app_scope.dart';
import 'core/models/edge_ai_runtime.dart';
import 'core/models/model_manager.dart';
import 'core/pack/pack_installer.dart';
import 'core/pack/pack_store.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/buttons.dart';
import 'features/card/services/resolver.dart';
import 'features/check/services/flagged_store.dart';
import 'features/check/services/inbox_scanner.dart';
import 'features/check/services/scan_index.dart';
import 'features/check/services/sms_inbox.dart';
import 'features/check/screens/check_screen.dart';
import 'features/check/screens/result_screen.dart';
import 'features/check/services/android_watcher.dart';
import 'features/check/services/message_watcher.dart';
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
  MessageWatcher? _watcher;
  InboxScanner? _scanner;
  Object? _error;

  final _navigator = GlobalKey<NavigatorState>();
  final _share = ShareEntry();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Back on screen: pick up texts that arrived while the phone had the app
  /// frozen, and re-check whether it may run in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_scanner?.catchUp());
    unawaited(_watcher?.refreshBackground());
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final store = PackStore.open(await installBundledPack());
      store.meta; // Fails here, not on first use, if the pack is unreadable.
      final support = await getApplicationSupportDirectory();
      final models = ModelManager(
        runtime: EdgeAiRuntime(),
        intents: store.intents(),
        cacheFile: File(p.join(support.path, 'intent-vectors.json')),
        scamExamples: store.scamExamples(),
        scamCacheFile: File(p.join(support.path, 'scam-vectors.json')),
        firstAidCards: store.firstAidCards(),
        firstAidCacheFile: File(p.join(support.path, 'first-aid-vectors.json')),
      );
      final senders = store.officialSenders();
      final checker = MessageChecker(
        senders: senders,
        shorteners: store.linkShorteners(),
        neutralHosts: store.neutralHosts(),
        gambling: store.gamblingRules(),
        phrases: () => models.scamPhrases,
      );
      // Flagged messages live in their own file, apart from the pack.
      final kept = sqlite3.open(p.join(support.path, 'flagged.sqlite'));
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
      final watcher = MessageWatcher(
        source: const AndroidNotificationSource(),
        alerter: LocalAlerter(),
        background: const AndroidBackgroundRunner(),
        checker: checker,
        flagged: flagged,
        wording: store.scamReasons(),
        settingsFile: File(p.join(support.path, 'automatic-checking')),
      );
      unawaited(watcher.start(_openFlagged));
      unawaited(scanner.catchUp());
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
        _watcher = watcher;
        _scanner = scanner;
      });
      // Text shared while the app was closed, then anything shared later.
      _share.listen(_openShared);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openShared());
    } on Object catch (error) {
      setState(() => _error = error);
    }
  }

  /// Opens the Check screen with whatever another app handed over.
  Future<void> _openShared() async {
    final shared = await _share.take();
    if (shared == null || !mounted) return;
    unawaited(
      _navigator.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => CheckScreen(
            initialText: shared.text,
            sharedWithoutText: shared.text == null,
          ),
        ),
      ),
    );
  }

  /// Opens the result behind a tapped scam alert.
  void _openFlagged(int id) {
    final message = _flagged?.byId(id);
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigator.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(result: message.result),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watcher?.dispose();
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
    final watcher = _watcher;
    final scanner = _scanner;
    if (store == null ||
        location == null ||
        models == null ||
        checker == null ||
        flagged == null ||
        watcher == null ||
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
      watcher: watcher,
      scanner: scanner,
      child: MaterialApp(
        title: 'Hudyat',
        navigatorKey: _navigator,
        theme: hudyatTheme(),
        home: const HomeScreen(),
      ),
    );
  }
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
