import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import 'flagged_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';
import 'timed_check_screen.dart';

/// Paste a message and check it. Also where a message shared or selected in
/// another app lands: it arrives as [initialText] and is checked at once.
class CheckScreen extends StatefulWidget {
  const CheckScreen({
    this.initialText,
    this.sharedWithoutText = false,
    super.key,
  });

  /// Text handed over by the share sheet or the text selection menu.
  final String? initialText;

  /// Something was shared that had no text in it, such as a photo.
  final bool sharedWithoutText;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  late final _message = TextEditingController(text: widget.initialText);
  final _sender = TextEditingController();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (_message.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final text = _message.text.trim();
    if (text.isEmpty || _checking) return;
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    try {
      final result = await scope.checker.check(text, sender: _sender.text);
      // Only flagged results are kept; a clear one leaves no trace.
      scope.flagged.keep(result);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: const TopBar(title: 'Check a message'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HudyatShape.gutter),
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Is this message real?',
                style: HudyatText.title,
              ),
            ),
            const SizedBox(height: 18),
            if (widget.sharedWithoutText) ...[
              const Notice(
                title: 'Nothing to check was shared',
                body:
                    'Hudyat checks text only. Paste the message below, or '
                    'select its text and choose "Check with Hudyat".',
              ),
              const SizedBox(height: 18),
            ],
            const Text.rich(
              TextSpan(
                text: 'Message',
                style: TextStyle(fontSize: 18, fontWeight: .w700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              textCapitalization: .sentences,
              style: HudyatText.body,
              decoration: const InputDecoration(
                hintText: 'Paste the message here.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            const Text.rich(
              TextSpan(
                text: 'Sender, if you know it',
                style: HudyatText.bodyBold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sender,
              style: HudyatText.data.copyWith(
                fontSize: 15,
                color: HudyatColors.ink,
              ),
              decoration: const InputDecoration(hintText: 'Number or name'),
              textInputAction: .done,
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _checking ? 'Checking…' : 'Check',
              gloss: _checking ? null : 'Suriin',
              onPressed: _checking || _message.text.trim().isEmpty
                  ? null
                  : _check,
            ),
            const SizedBox(height: 8),
            const Text(
              'Checked on this phone. The message is not sent anywhere.',
              style: HudyatText.gloss,
            ),
            const SizedBox(height: 18),
            const Text(
              'You can also check from another app',
              style: HudyatText.gloss,
            ),
            const SizedBox(height: 8),
            const Panel(
              primary: false,
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Share',
                      style: HudyatText.bodyBold,
                      children: [
                        TextSpan(
                          text: ' a message, then choose Hudyat.',
                          style: HudyatText.body,
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: 'Select',
                      style: HudyatText.bodyBold,
                      children: [
                        TextSpan(
                          text: ' the text, then tap "Check with Hudyat".',
                          style: HudyatText.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ListenableBuilder(
              listenable: scope.flagged,
              builder: (context, _) => SecondaryButton(
                label: 'Flagged messages',
                gloss: '${scope.flagged.count} kept',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FlaggedScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Scan my messages',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
              ),
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: scope.timed,
              builder: (context, _) => SecondaryButton(
                label: 'Automatic checking',
                gloss:
                    scope.timed.status.on ||
                        (scope.protection?.status.appsOn ?? false)
                    ? 'ON'
                    : 'OFF',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TimedCheckScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: HudyatShape.ruleBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Official list: bettergovph/bettergov, company websites\n'
                  'Pack built ${scope.store.meta.buildDate}',
                  style: HudyatText.data,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
