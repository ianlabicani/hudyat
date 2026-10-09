import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _shape = RoundedRectangleBorder(borderRadius: HudyatShape.radius);
const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

/// Label with an optional Filipino gloss. Wraps instead of clipping when the
/// text is large or the screen is narrow.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.label, this.gloss, this.glossColor);

  final String label;
  final String? gloss;
  final Color glossColor;

  @override
  Widget build(BuildContext context) {
    final gloss = this.gloss;
    if (gloss == null) return Text(label, textAlign: .center);
    return Wrap(
      alignment: .center,
      crossAxisAlignment: .center,
      spacing: 8,
      children: [
        Text(label),
        Text(
          gloss,
          style: TextStyle(fontSize: 14, fontWeight: .w400, color: glossColor),
        ),
      ],
    );
  }
}

/// The main action of a screen: ink fill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.gloss,
    super.key,
  });

  final String label;
  final String? gloss;

  /// Null shows the disabled state.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: HudyatColors.ink,
        foregroundColor: HudyatColors.surface,
        disabledBackgroundColor: HudyatColors.disabledFill,
        disabledForegroundColor: HudyatColors.disabledText,
        minimumSize: const Size.fromHeight(52),
        padding: _padding,
        shape: _shape,
        textStyle: HudyatText.button,
      ),
      child: _ButtonLabel(label, gloss, HudyatColors.rule),
    );
  }
}

/// A second choice next to or below the main action: outlined.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.gloss,
    this.expand = true,
    super.key,
  });

  final String label;
  final String? gloss;
  final VoidCallback? onPressed;

  /// Full width by default; false sizes the button to its label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: HudyatColors.surface,
        foregroundColor: HudyatColors.ink,
        side: HudyatShape.primaryBorder,
        minimumSize: expand ? const Size.fromHeight(52) : const Size(64, 44),
        padding: _padding,
        shape: _shape,
        textStyle: HudyatText.button.copyWith(fontSize: expand ? 17 : 15),
      ),
      child: _ButtonLabel(label, gloss, HudyatColors.muted),
    );
  }
}

/// Opens the dialer. The only place the call accent is used as a fill.
class CallButton extends StatelessWidget {
  const CallButton({
    required this.onPressed,
    this.label = 'Call',
    this.gloss,
    this.large = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final String? gloss;

  /// Full-width, taller variant for a screen's single call action.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.call, size: large ? 22 : 18),
      label: _ButtonLabel(label, gloss, HudyatColors.surface),
      style: FilledButton.styleFrom(
        backgroundColor: HudyatColors.call,
        foregroundColor: HudyatColors.surface,
        disabledBackgroundColor: HudyatColors.disabledFill,
        disabledForegroundColor: HudyatColors.disabledText,
        minimumSize: large ? const Size.fromHeight(60) : const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: _shape,
        textStyle: HudyatText.button.copyWith(fontSize: large ? 20 : 16),
      ),
    );
  }
}
