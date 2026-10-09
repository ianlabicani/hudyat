import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../services/timed_check.dart';

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
  }

  Future<void> _turnOn() async {
    final timed = AppScope.of(context).timed;
    setState(() {
      _asking = true;
      _refused = false;
    });
    final on = await timed.turnOn();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _refused = !on;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timed = AppScope.of(context).timed;
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
                const SizedBox(height: 6),
                const Text(
                  'Awtomatikong suriin ang mga text ko',
                  style: HudyatText.gloss,
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
                    'Hudyat alerts you only for "Mukhang scam", at the next '
                    'check: up to ${status.intervalLabel} after the text '
                    'arrives, or at once when you open Hudyat. Add the '
                    'Hudyat widget to your home screen to see the counts.',
                    style: HudyatText.secondary,
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Turn off',
                    gloss: 'I-off',
                    onPressed: timed.turnOff,
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

  static String _two(int value) => value.toString().padLeft(2, '0');

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
              '${status.gambling} sugal promo',
              style: HudyatText.body,
            ),
            Text(
              '${status.total} texts checked · last at '
              '${_two(at.hour)}:${_two(at.minute)}',
              style: HudyatText.data,
            ),
          ],
        ],
      ),
    );
  }
}
