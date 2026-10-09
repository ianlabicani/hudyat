import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../services/message_watcher.dart';

/// Explains automatic checking and turns it on or off. It is off until the
/// user turns it on here, and it needs Android's notification access.
class WatcherSetupScreen extends StatefulWidget {
  const WatcherSetupScreen({super.key});

  @override
  State<WatcherSetupScreen> createState() => _WatcherSetupScreenState();
}

class _WatcherSetupScreenState extends State<WatcherSetupScreen>
    with WidgetsBindingObserver {
  bool _asking = false;
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user may have just come back from Android's battery setting.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppScope.of(context).watcher.refreshBackground();
    }
  }

  Future<void> _turnOn() async {
    final watcher = AppScope.of(context).watcher;
    setState(() {
      _asking = true;
      _refused = false;
    });
    final on = await watcher.turnOn();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _refused = !on;
    });
  }

  @override
  Widget build(BuildContext context) {
    final watcher = AppScope.of(context).watcher;
    return Scaffold(
      appBar: const TopBar(title: 'Automatic checking'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: watcher,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(HudyatShape.gutter),
            children: [
              Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Check incoming messages for scams',
                        style: HudyatText.title.copyWith(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tag(watcher.isOn ? 'ON' : 'OFF'),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Awtomatikong suriin ang mga dumarating na mensahe',
                style: HudyatText.gloss,
              ),
              const SizedBox(height: 18),
              const _Fact(
                title: 'What Hudyat reads',
                body:
                    'Notifications from your SMS app, Messenger, Viber, '
                    'WhatsApp and Telegram. Every other notification is '
                    'ignored.',
              ),
              const SizedBox(height: 10),
              const _Fact(
                title: 'What it keeps',
                body:
                    'Only messages checked as "Mukhang scam" or '
                    '"Mag-ingat". Everything else is discarded after the '
                    'check. You can clear the list any time.',
              ),
              const SizedBox(height: 10),
              const _Fact(
                title: 'What leaves the phone',
                body:
                    'Nothing. The check runs on this phone, with or '
                    'without signal.',
              ),
              const SizedBox(height: 18),
              if (!watcher.isOn) ...[
                Notice(
                  title: _refused
                      ? 'Notification access was not turned on'
                      : 'Android will ask for notification access',
                  body:
                      'Turn on Hudyat in the list that opens. If the switch '
                      'is greyed out, open Hudyat\'s App info, tap the menu '
                      'and choose "Allow restricted settings", then try '
                      'again.',
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
                _Activity(watcher: watcher),
                const SizedBox(height: 14),
                if (!watcher.runsInBackground) ...[
                  Notice(
                    title: 'This phone will pause Hudyat in the background',
                    body:
                        'Messages are then checked only when you open '
                        'Hudyat again. To be alerted as they arrive, let '
                        'Hudyat run in the background: allow it when '
                        'Android asks, or set its battery use to '
                        '"Unrestricted" in App info.',
                    action: SecondaryButton(
                      label: 'Allow',
                      expand: false,
                      onPressed: watcher.allowBackground,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  'Hudyat alerts you only for "Mukhang scam". It works while '
                  'the app is open or in the background. A long message may '
                  'be cut short in its notification.',
                  style: HudyatText.secondary,
                ),
                const SizedBox(height: 18),
                SecondaryButton(
                  label: 'Turn off',
                  gloss: 'I-off',
                  onPressed: watcher.turnOff,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

/// What automatic checking has done since the app was opened: proof that
/// messages are arriving, including the ones with nothing wrong.
class _Activity extends StatelessWidget {
  const _Activity({required this.watcher});

  final MessageWatcher watcher;

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final at = watcher.lastCheckedAt;
    final delay = watcher.lastDelay;
    final late = delay != null && delay.inSeconds >= 5;
    return Panel(
      primary: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          Text(
            watcher.checkedCount == 1
                ? '1 message checked since you opened Hudyat'
                : '${watcher.checkedCount} messages checked since you opened '
                      'Hudyat',
            style: HudyatText.bodyBold,
          ),
          if (at == null)
            const Text(
              'Waiting for the first message.',
              style: HudyatText.secondary,
            )
          else
            Text(
              [
                'Last: ${_two(at.hour)}:${_two(at.minute)}:${_two(at.second)}',
                watcher.lastVerdict?.label ?? '',
                if (delay != null)
                  'checked ${delay.inSeconds}s after it arrived',
              ].join(' · '),
              style: HudyatText.data,
            ),
          if (late)
            const Text(
              'The phone had Hudyat paused when this one arrived, so it was '
              'checked when Hudyat was opened.',
              style: HudyatText.gloss,
            ),
        ],
      ),
    );
  }
}
