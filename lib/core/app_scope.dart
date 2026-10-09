import 'package:flutter/widgets.dart';

import '../features/card/services/resolver.dart';
import '../features/check/services/flagged_store.dart';
import '../features/check/services/inbox_scanner.dart';
import '../features/check/services/message_checker.dart';
import '../features/check/services/protection_platform.dart';
import '../features/check/services/timed_check.dart';
import '../features/location/state/location_controller.dart';
import 'models/model_manager.dart';
import 'pack/pack_store.dart';

/// The app's long-lived services, created once at start-up.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.store,
    required this.resolver,
    required this.location,
    required this.models,
    required this.checker,
    required this.flagged,
    required this.timed,
    required this.scanner,
    this.protection,
    required super.child,
    super.key,
  });

  final PackStore store;
  final Resolver resolver;
  final LocationController location;
  final ModelManager models;
  final MessageChecker checker;
  final FlaggedStore flagged;
  final TimedCheck timed;
  final InboxScanner scanner;
  final ProtectionController? protection;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      store != oldWidget.store ||
      resolver != oldWidget.resolver ||
      location != oldWidget.location ||
      models != oldWidget.models ||
      checker != oldWidget.checker ||
      flagged != oldWidget.flagged ||
      timed != oldWidget.timed ||
      scanner != oldWidget.scanner ||
      protection != oldWidget.protection;
}
