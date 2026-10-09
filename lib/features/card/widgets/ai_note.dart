import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dashed_panel.dart';

/// The AI-written sentences under a card, always labelled. Takes no space
/// until the first words arrive, and disappears if the stream ends empty.
class AiNote extends StatefulWidget {
  const AiNote({required this.text, super.key});

  /// The note so far, re-emitted as it grows.
  final Stream<String> text;

  @override
  State<AiNote> createState() => _AiNoteState();
}

class _AiNoteState extends State<AiNote> {
  StreamSubscription<String>? _subscription;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _subscription = widget.text.listen(
      (text) => setState(() => _text = text),
      onError: (Object _) => setState(() => _text = ''),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: DashedPanel(
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: HudyatColors.ink,
                borderRadius: HudyatShape.badgeRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'AI-WRITTEN · MAY BE WRONG',
                  style: HudyatText.data.copyWith(color: HudyatColors.surface),
                ),
              ),
            ),
            Text(_text, style: HudyatText.body),
          ],
        ),
      ),
    );
  }
}
