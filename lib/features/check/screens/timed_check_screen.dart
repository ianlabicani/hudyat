import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../services/timed_check.dart';
import '../services/protection_platform.dart';

/// Explains automatic checking and turns it on or off. It is off until the
/// user turns it on here, and it needs access to the SMS inbox.
class TimedCheckScreen extends StatefulWidget {
  const TimedCheckScreen({super.key});

  @override
  State<TimedCheckScreen> createState() => _TimedCheckScreenState();
}

class _TimedCheckScreenState extends State<TimedCheckScreen> {
  bool _asking = false;
  bool _refused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context).timed.refresh();
    AppScope.of(context).protection?.refresh();
  }

  Future<void> _turnOn() async {
    final scope = AppScope.of(context);
    final timed = scope.timed;
    final protection = scope.protection;
    setState(() {
      _asking = true;
      _refused = false;
    });
    final on = await timed.turnOn();
    if (on) {
      await protection?.requestSmsCapture();
      await protection?.refresh();
    }
    if (!mounted) return;
    setState(() {
      _asking = false;
      // Off because the check itself failed is not a refusal of access.
      _refused = !on && timed.failure == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final timed = scope.timed;
    if (scope.protection case final protection?) {
      return _liveScreen(timed, protection);
    }
    return Scaffold(
      appBar: const TopBar(title: 'Automatic checking'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: timed,
          builder: (context, _) {
            final status = timed.status;
            return ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Check my texts for scams',
                          style: HudyatText.title.copyWith(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tag(status.on ? 'ON' : 'OFF'),
                  ],
                ),
                const SizedBox(height: 18),
                _Fact(
                  title: 'What Hudyat reads',
                  body:
                      'Your text messages (SMS) from the last 7 days, about '
                      'every ${status.intervalLabel} and whenever you open '
                      'Hudyat. Not Messenger, Viber or WhatsApp: share or '
                      'paste those into Hudyat to check them.',
                ),
                const SizedBox(height: 10),
                const _Fact(
                  title: 'What it keeps',
                  body:
                      'Only texts checked as "Mukhang scam" or "Mag-ingat", '
                      'in the Flagged list. The home screen widget shows '
                      'counts only, never a message.',
                ),
                const SizedBox(height: 10),
                const _Fact(
                  title: 'What leaves the phone',
                  body:
                      'Nothing. The check runs on this phone, with or '
                      'without signal.',
                ),
                const SizedBox(height: 18),
                if (!status.on) ...[
                  Notice(
                    title: _refused
                        ? 'SMS access was not given'
                        : 'Android will ask for SMS access',
                    body:
                        'Allow it so Hudyat can read your texts. If Android '
                        'does not ask, open Hudyat\'s App info, tap the menu '
                        'and choose "Allow restricted settings", then try '
                        'again. It will also ask to show notifications, for '
                        'the scam alert.',
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: _asking ? 'Waiting for access…' : 'Turn on',
                    gloss: _asking ? null : 'I-on',
                    onPressed: _asking ? null : _turnOn,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: "Not now. I'll check messages myself.",
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ] else ...[
                  _Counts(status: status),
                  const SizedBox(height: 14),
                  if (!status.hasAccess) ...[
                    const Notice(
                      title: 'SMS access was taken away',
                      body:
                          'Hudyat cannot read your texts until it is allowed '
                          'again. Turn automatic checking off and on.',
                    ),
                    const SizedBox(height: 14),
                  ] else if (!status.canNotify) ...[
                    const Notice(
                      title: 'Alerts are turned off for Hudyat',
                      body:
                          'Texts are still checked and counted on the '
                          'widget. To be alerted, allow notifications for '
                          'Hudyat in Settings.',
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Checks are scheduled about every ${status.intervalLabel}. '
                    'Android may delay them. Opening Hudyat also checks recent texts. '
                    'Hudyat alerts you only for "Mukhang scam". Add the '
                    'Hudyat widget to your home screen to see the counts.',
                    style: HudyatText.secondary,
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(label: 'Turn off', onPressed: timed.turnOff),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _liveScreen(TimedCheck timed, ProtectionController protection) {
    return Scaffold(
      appBar: const TopBar(title: 'Automatic checking'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([timed, protection]),
          builder: (context, _) {
            final status = timed.status;
            final live = protection.status;
            final active = status.on || live.appsOn;
            return ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Live scam protection',
                          style: HudyatText.title.copyWith(fontSize: 24),
                        ),
                      ),
                    ),
                    Tag(active ? 'ON' : 'OFF'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hudyat checks incoming SMS and selected messaging app '
                  'previews on this phone. It alerts only for "Mukhang scam".',
                  style: HudyatText.secondary,
                ),
                const SizedBox(height: 16),
                _Fact(
                  title: 'SMS',
                  body: status.on
                      ? live.smsCapture
                            ? 'Live SMS checking is ready. The 12-hour inbox '
                                  'check also recovers missed messages.'
                            : 'The inbox recovery is on, but live SMS access '
                                  'is not allowed yet.'
                      : 'Turn on SMS checking to allow live capture and '
                            'the 12-hour recovery check.',
                ),
                const SizedBox(height: 10),
                if (!status.on) ...[
                  if (_refused)
                    const Notice(
                      title: 'SMS access was not given',
                      body:
                          'SMS checking stays off. Messaging app coverage '
                          'can still be enabled separately.',
                    ),
                  if (timed.failure case final failure?)
                    Notice(
                      title: 'SMS checking could not start',
                      body:
                          'This is a fault in Hudyat, not a missing '
                          'permission. Try again. ($failure)',
                    ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _asking ? 'Waiting for access…' : 'Turn on SMS',
                    onPressed: _asking ? null : _turnOn,
                  ),
                ] else ...[
                  _Counts(status: status),
                  if (!status.hasAccess || !live.smsCapture) ...[
                    const SizedBox(height: 10),
                    Notice(
                      title: !status.hasAccess
                          ? 'SMS inbox access was taken away'
                          : 'Live SMS access is off',
                      body: !status.hasAccess
                          ? 'Live SMS can still work if its separate access '
                                'is allowed, but the 12-hour recovery cannot run.'
                          : 'Allow incoming SMS access for immediate checks. '
                                'Inbox recovery continues with its own access.',
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Allow live SMS access',
                      onPressed: protection.requestSmsCapture,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Turn off SMS',
                    onPressed: () async {
                      await timed.turnOff();
                      await protection.refresh();
                    },
                  ),
                ],
                const SizedBox(height: 20),
                _Fact(
                  title: 'Messaging apps',
                  body: live.appsOn
                      ? live.appsReady
                            ? 'Notification access is connected. Selected '
                                  'app previews are checked as they arrive.'
                            : 'Allow Hudyat notification access in Android '
                                  'settings. This is separate from scam alerts.'
                      : 'Enable this to check visible previews from selected '
                            'messaging apps. Android asks for notification access.',
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: live.appsOn
                      ? 'Turn off app checking'
                      : 'Turn on app checking',
                  onPressed: () async {
                    await protection.setAppsOn(!live.appsOn);
                    if (!live.appsOn && !protection.status.notificationAccess) {
                      await protection.openNotificationAccess();
                    }
                  },
                ),
                if (live.appsOn) ...[
                  if (!live.notificationAccess) ...[
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Open notification access settings',
                      onPressed: protection.openNotificationAccess,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Apps to check', style: HudyatText.bodyBold),
                  for (final source in live.sources.where((s) => s.installed))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.name, style: HudyatText.body),
                      subtitle: Text(source.package, style: HudyatText.data),
                      value: source.enabled,
                      onChanged: (enabled) =>
                          protection.setSourceEnabled(source.package, enabled),
                    ),
                ],
                const SizedBox(height: 20),
                _Fact(
                  title: 'Scam alerts',
                  body: live.canAlert
                      ? 'Ready. Only strong "Mukhang scam" findings notify you.'
                      : 'Alerts are turned off for Hudyat. Findings are still '
                            'saved; allow Hudyat notifications and its Scam '
                            'alerts channel to see warnings.',
                ),
                if (!live.canAlert) ...[
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Allow scam alerts',
                    onPressed: () async {
                      if (!await timed.requestAlerts()) {
                        await protection.openAlertSettings();
                      }
                      await protection.refresh();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text(switch (live.lastProcessed) {
                  null => 'No live message processed yet.',
                  final at => 'Last processed: ${_when(at)}',
                }, style: HudyatText.data),
                if (live.failure case final failure?) ...[
                  const SizedBox(height: 8),
                  Notice(
                    title: 'A recent check failed',
                    body: failure == 'pack_unavailable'
                        ? 'Open Hudyat to prepare its local data pack, then '
                              'try again.'
                        : 'Open Hudyat again. If checks still fail, review '
                              'SMS and notification access in Android settings.',
                  ),
                ],
                const SizedBox(height: 16),
                const _Fact(
                  title: 'What Hudyat keeps',
                  body:
                      'Only flagged message text stays in the Flagged list '
                      'on this phone. Other message text is discarded.',
                ),
                const SizedBox(height: 10),
                const _Fact(
                  title: 'Coverage limits',
                  body:
                      'Hidden previews, muted apps, and Android-redacted '
                      'content may not be available. Android 15 can hide some '
                      'OTP text from notification access. Missing text is '
                      'never treated as a clear message.',
                ),
                const SizedBox(height: 10),
                const _Fact(
                  title: 'What leaves the phone',
                  body:
                      'Nothing from these checks. Fast rules run offline '
                      'without loading an AI model in the background.',
                ),
                if (active) ...[
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Turn off all protection',
                    onPressed: () async {
                      await protection.stopAll();
                      await timed.refresh();
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// A time as "2026-10-10 06:12".
String _when(DateTime at) =>
    '${at.year}-${_two(at.month)}-${_two(at.day)} '
    '${_two(at.hour)}:${_two(at.minute)}';

class _Fact extends StatelessWidget {
  const _Fact({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Panel(
      primary: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          Text(title, style: HudyatText.bodyBold),
          Text(body, style: HudyatText.secondary),
        ],
      ),
    );
  }
}

/// What the last check found, the same numbers the widget shows.
class _Counts extends StatelessWidget {
  const _Counts({required this.status});

  final TimedStatus status;

  @override
  Widget build(BuildContext context) {
    final at = status.checkedAt;
    return Panel(
      primary: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          const Text('Texts from the last 7 days', style: HudyatText.bodyBold),
          if (at == null)
            const Text('Not checked yet.', style: HudyatText.secondary)
          else ...[
            Text(
              '${status.scam} Mukhang scam · ${status.caution} Mag-ingat · '
              '${status.gambling} Sugal promo',
              style: HudyatText.body,
            ),
            Text(
              '${status.total} texts checked · last at '
              '${TimeOfDay.fromDateTime(at).format(context)}',
              style: HudyatText.data,
            ),
          ],
        ],
      ),
    );
  }
}
