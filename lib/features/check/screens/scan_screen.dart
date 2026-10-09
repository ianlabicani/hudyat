import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../services/inbox_scanner.dart';
import 'flagged_screen.dart';

/// Checks the texts already in the SMS inbox, for a chosen range. Texts an
/// earlier scan checked are skipped.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  ScanRange _range = ScanRange.month;
  bool _wording = false;

  /// Texts not yet checked in the chosen range; null until SMS access is
  /// given, since counting needs to read the inbox.
  int? _pending;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _count();
    }
  }

  Future<void> _count() async {
    final pending = await AppScope.of(context).scanner.pending(_range);
    if (mounted) setState(() => _pending = pending);
  }

  Future<void> _scan() async {
    await AppScope.of(context).scanner.scan(_range, wording: _wording);
    if (mounted) await _count();
  }

  void _pick(ScanRange range) {
    setState(() {
      _range = range;
      _pending = null;
    });
    _count();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = AppScope.of(context).scanner;
    return Scaffold(
      appBar: const TopBar(title: 'Scan my messages'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: scanner,
          builder: (context, _) {
            final summary = scanner.last;
            final pending = _pending;
            return ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Check the texts already on this phone',
                    style: HudyatText.title.copyWith(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Suriin ang mga text na nasa phone na',
                  style: HudyatText.gloss,
                ),
                const SizedBox(height: 18),
                const Panel(
                  primary: false,
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Hudyat reads your SMS inbox on this phone and checks '
                    'each text. Only "Mukhang scam" and "Mag-ingat" texts '
                    'are kept. For the rest it remembers only that they '
                    'were checked, not what they say. Nothing leaves the '
                    'phone, and no text is changed or deleted.',
                    style: HudyatText.secondary,
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeading(title: 'How far back', gloss: 'Saklaw'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final range in ScanRange.values)
                      ChoiceChip(
                        label: Text(range.label),
                        selected: range == _range,
                        onSelected: scanner.running
                            ? null
                            : (_) => _pick(range),
                        showCheckmark: false,
                        backgroundColor: HudyatColors.surface,
                        selectedColor: HudyatColors.ink,
                        labelStyle: HudyatText.bodyBold.copyWith(
                          fontSize: 15,
                          color: range == _range
                              ? HudyatColors.surface
                              : HudyatColors.ink,
                        ),
                        side: HudyatShape.secondaryBorder,
                        shape: const RoundedRectangleBorder(
                          borderRadius: HudyatShape.radius,
                        ),
                        materialTapTargetSize: .padded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    if (pending != null)
                      pending == 0
                          ? 'Nothing new to check in this range'
                          : '$pending not yet checked in this range',
                    'Already checked: ${scanner.remembered}',
                  ].join(' · '),
                  style: HudyatText.data,
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: HudyatColors.ink,
                  value: _wording && scanner.canCheckWording,
                  onChanged: scanner.running || !scanner.canCheckWording
                      ? null
                      : (value) => setState(() => _wording = value),
                  title: const Text(
                    'Also check the wording',
                    style: HudyatText.bodyBold,
                  ),
                  subtitle: Text(
                    scanner.canCheckWording
                        ? 'Slower: about a second per text. You can stop '
                              'and continue later.'
                        : 'Needs the language model, which is not ready.',
                    style: HudyatText.gloss,
                  ),
                ),
                const SizedBox(height: 10),
                if (scanner.refused) ...[
                  const Notice(
                    title: 'SMS access was not given',
                    body:
                        'Hudyat cannot scan without it. If Android does not '
                        'ask, open Hudyat\'s App info, tap the menu and '
                        'choose "Allow restricted settings", then allow SMS '
                        'under Permissions. Pasting and sharing a message '
                        'still work without it.',
                  ),
                  const SizedBox(height: 14),
                ],
                if (scanner.running) ...[
                  LinearProgressIndicator(
                    value: scanner.total == 0
                        ? null
                        : scanner.done / scanner.total,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scanner.total == 0
                        ? 'Reading the inbox…'
                        : scanner.wordingPass
                        ? 'Checking the wording: ${scanner.done} of '
                              '${scanner.total}'
                        : 'Checking ${scanner.done} of ${scanner.total}',
                    style: HudyatText.secondary,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(label: 'Stop', onPressed: scanner.stop),
                ] else
                  PrimaryButton(
                    label: 'Scan',
                    gloss: 'I-scan',
                    onPressed: _scan,
                  ),
                if (summary != null) ...[
                  const SizedBox(height: 22),
                  _Summary(summary: summary),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Flagged messages',
                    gloss: '${AppScope.of(context).flagged.count} kept',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FlaggedScreen(),
                      ),
                    ),
                  ),
                ],
                if (scanner.remembered > 0 && !scanner.running) ...[
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Forget what was checked',
                    onPressed: () {
                      scanner.forget();
                      _count();
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The next scan then checks every text again. Flagged '
                    'messages stay in their list.',
                    style: HudyatText.gloss,
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

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final ScanSummary summary;

  @override
  Widget build(BuildContext context) {
    final nothingNew = summary.checked == 0 && summary.worded == 0;
    return Panel(
      child: Column(
        crossAxisAlignment: .start,
        spacing: 6,
        children: [
          Text(
            summary.stopped
                ? 'Stopped part-way'
                : summary.read == 0
                ? 'No texts in this range'
                : nothingNew
                ? 'Nothing new to check'
                : 'Scan finished',
            style: HudyatText.bodyBold,
          ),
          Text(
            '${summary.range.label}: ${summary.read} read · '
            '${summary.skipped} already checked, skipped · '
            '${summary.checked} checked now',
            style: HudyatText.data,
          ),
          if (!nothingNew) ...[
            Text('${summary.scam} Mukhang scam', style: HudyatText.bodyBold),
            Text('${summary.caution} Mag-ingat', style: HudyatText.bodyBold),
            Text(
              '${summary.clear} with no problem found',
              style: HudyatText.body,
            ),
          ],
          if (summary.worded > 0)
            Text(
              'Wording also checked on ${summary.worded}',
              style: HudyatText.data,
            ),
          if (summary.stopped)
            const Text(
              'What was checked is remembered. Scan again to continue.',
              style: HudyatText.gloss,
            ),
        ],
      ),
    );
  }
}
