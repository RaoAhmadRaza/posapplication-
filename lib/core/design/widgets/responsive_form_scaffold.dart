import 'package:flutter/material.dart';
import '../../state/theme_controller.dart';
import '../app_colors.dart';
import '../app_typography.dart';

/// Centered auth form scaffold — warm paper background, constrained content
/// column, Clash Display title. A small brightness toggle (top-right) flips
/// light / dark "Counter mode".
class ResponsiveFormScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  const ResponsiveFormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: AppTypography.largeTitle
                                  .copyWith(color: lum.textPrimary),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: AppTypography.subtitleMuted
                                    .copyWith(color: lum.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 32),
                            child,
                            if (footer != null) ...[
                              const SizedBox(height: 24),
                              footer!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                tooltip: 'Toggle theme',
                onPressed: ThemeController.toggle,
                icon: Icon(
                  lum.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: lum.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
