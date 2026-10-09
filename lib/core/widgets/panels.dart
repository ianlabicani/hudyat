import 'package:flutter/material.dart';

import '../pack/pack_store.dart';
import '../theme/tokens.dart';

/// A white box with the primary or secondary border. Most rows sit in one.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.primary = true,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final bool primary;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HudyatColors.surface,
        borderRadius: HudyatShape.radius,
        border: Border.fromBorderSide(
          primary ? HudyatShape.primaryBorder : HudyatShape.secondaryBorder,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The "!" box: one bold line and one sentence, with an optional action.
class Notice extends StatelessWidget {
  const Notice({required this.title, this.body, this.action, super.key});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final action = this.action;
    return Panel(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          const ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                border: Border.fromBorderSide(HudyatShape.primaryBorder),
              ),
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Text('!', style: TextStyle(fontWeight: .w700)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 4,
              children: [
                Text(title, style: HudyatText.bodyBold),
                if (body != null) Text(body, style: HudyatText.secondary),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: action,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Labels which level a hotline list comes from. Outlined means the user's
/// own city; filled means a wider fallback.
class LevelBadge extends StatelessWidget {
  const LevelBadge({required this.level, this.name, super.key});

  final HotlineLevel level;
  final String? name;

  String get text {
    final label = switch (level) {
      HotlineLevel.city => 'CITY',
      HotlineLevel.province => 'PROVINCE',
      HotlineLevel.national => 'NATIONAL',
    };
    final name = this.name;
    return name == null || level == HotlineLevel.national
        ? label
        : '$label · ${name.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final filled = level != HotlineLevel.city;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? HudyatColors.ink : null,
        borderRadius: HudyatShape.badgeRadius,
        border: const Border.fromBorderSide(HudyatShape.secondaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: HudyatText.data.copyWith(
            color: filled ? HudyatColors.surface : HudyatColors.ink,
          ),
        ),
      ),
    );
  }
}

/// A small outlined tag, such as a record kind on a search result.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: HudyatShape.badgeRadius,
        border: Border.fromBorderSide(HudyatShape.secondaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text.toUpperCase(),
          style: HudyatText.data.copyWith(color: HudyatColors.ink),
        ),
      ),
    );
  }
}

/// A section title with its Filipino gloss and an optional trailing label.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    this.gloss,
    this.trailing,
    super.key,
  });

  final String title;
  final String? gloss;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final gloss = this.gloss;
    final trailing = this.trailing;
    // A Wrap, so with large text the trailing label drops below the title
    // instead of running off the screen.
    return Wrap(
      alignment: .spaceBetween,
      spacing: 8,
      runSpacing: 6,
      children: [
        Semantics(
          header: true,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(title, style: HudyatText.section),
              if (gloss != null) Text(gloss, style: HudyatText.gloss),
            ],
          ),
        ),
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
      ],
    );
  }
}

/// Source credits and the pack build date. Goes at the bottom of every card.
class PackFooter extends StatelessWidget {
  const PackFooter({
    required this.buildDate,
    this.hotlineSources = const [],
    this.showsPlaces = false,
    super.key,
  });

  final String buildDate;
  final List<String> hotlineSources;

  /// Places come from OpenStreetMap, which requires attribution.
  final bool showsPlaces;

  @override
  Widget build(BuildContext context) {
    final credits = [
      if (hotlineSources.isNotEmpty) 'Hotlines: ${hotlineSources.join(', ')}',
      if (showsPlaces) 'Places: © OpenStreetMap contributors',
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: HudyatShape.ruleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            if (credits.isNotEmpty)
              Text(credits.join(' · '), style: HudyatText.data),
            Text(
              'Pack built $buildDate. Numbers may be out of date.',
              style: HudyatText.data,
            ),
          ],
        ),
      ),
    );
  }
}

/// Top bar with the screen title and an optional Filipino gloss.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({required this.title, this.gloss, super.key});

  final String title;
  final String? gloss;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final gloss = this.gloss;
    return AppBar(
      title: Text.rich(
        TextSpan(
          text: title,
          children: [
            if (gloss != null)
              TextSpan(text: '  $gloss', style: HudyatText.gloss),
          ],
        ),
      ),
    );
  }
}
