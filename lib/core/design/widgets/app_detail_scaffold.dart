import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';

/// Body shell for a settings detail screen: a clay back button beside an
/// uppercase eyebrow, display title and description, over centred content.
///
/// Replaces the Material [AppBar] on screens that render inside the navigation
/// shell — the rail already carries the app chrome, so a second bar would
/// duplicate it.
class AppDetailScaffold extends StatelessWidget {
  const AppDetailScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
    this.maxContentWidth = 860,
    this.onBack,
    this.bottomBar,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget child;

  /// Controls rendered opposite the title (e.g. a create button).
  final List<Widget> actions;
  final double maxContentWidth;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;

  /// Optional sticky footer pinned below the scroll (e.g. a save bar).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Scaffold(
      backgroundColor: lum.paper,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            return SingleChildScrollView(
              padding: narrow
                  ? const EdgeInsets.fromLTRB(16, 20, 16, 40)
                  : const EdgeInsets.fromLTRB(32, 32, 32, 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        eyebrow: eyebrow,
                        title: title,
                        description: description,
                        actions: actions,
                        narrow: narrow,
                        onBack: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 26),
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actions,
    required this.narrow,
    required this.onBack,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;
  final bool narrow;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: lum.g400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppTypography.title1.copyWith(
            fontSize: narrow ? 23 : 26,
            color: lum.textPrimary,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 5),
          Text(
            description!,
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ],
      ],
    );

    final back = Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBack,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );

    // Actions drop under the heading when the row would crowd — they are
    // buttons with real labels, not icons that can shrink.
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              back,
              const SizedBox(width: 14),
              Expanded(child: heading),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [for (final a in actions) ...[a, const SizedBox(width: 10)]]),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        back,
        const SizedBox(width: 14),
        Expanded(child: heading),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ],
    );
  }
}
