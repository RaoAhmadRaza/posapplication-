import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../auth/presentation/controllers/profile_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../sync/presentation/widgets/sync_status_widget.dart';

/// Width at or above which sales screens use their wide layout. Matches the nav
/// shell's rail breakpoint so the rail and the desktop layouts appear together.
const kSalesWideBreakpoint = 900.0;

/// Shared chrome for every sales screen: the design's flat header (title, sync
/// chip, notifications, avatar) over a paper body.
///
/// Bespoke rather than a Material AppBar so the LUMINA heights (60 wide / 54
/// narrow) and the display-face title are exact.
class SalesScaffold extends StatelessWidget {
  const SalesScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading,
    this.maxContentWidth,
    this.padding,
    this.bottomBar,
  });

  final String title;
  final Widget child;

  /// Header actions, placed before the sync chip and bell.
  final List<Widget> actions;

  /// Optional leading control (e.g. a back arrow on a pushed screen).
  final Widget? leading;

  /// Centres and constrains the body, per the design's per-screen measures.
  final double? maxContentWidth;
  final EdgeInsets? padding;

  /// Pinned below the body (e.g. the payment sheet's Complete sale bar).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    Widget body = child;
    if (padding != null) {
      body = Padding(padding: padding!, child: body);
    }
    if (maxContentWidth != null) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: lum.paper,
      body: Column(
        children: [
          SalesHeader(title: title, actions: actions, leading: leading),
          Expanded(child: SafeArea(top: false, child: body)),
          ?bottomBar,
        ],
      ),
    );
  }

  /// Whether the current layout is the wide (desktop) one.
  static bool isWideOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kSalesWideBreakpoint;
}

/// The header bar itself, exposed so a screen that needs a custom body shell
/// (the POS terminal) can still use it.
class SalesHeader extends StatelessWidget {
  const SalesHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isWide = SalesScaffold.isWideOf(context);

    return Container(
      height: isWide ? 60 : 54,
      padding: EdgeInsets.only(left: isWide ? 26 : 16, right: isWide ? 20 : 8),
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title2.copyWith(
                  fontSize: isWide ? 19 : 17,
                  color: lum.textPrimary,
                ),
              ),
            ),
            ...actions,
            const SizedBox(width: 4),
            const SyncStatusWidget(),
            const NotificationBell(),
            const SizedBox(width: 4),
            SalesAvatar(size: isWide ? 34 : 30),
          ],
        ),
      ),
    );
  }
}

/// Signed-in user's initials, as the design's header avatar.
class SalesAvatar extends ConsumerWidget {
  const SalesAvatar({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final name = ref.watch(profileControllerProvider).value?.fullName ?? '';
    final initials = _initialsOf(name);

    return Semantics(
      label: name.isEmpty ? 'Account' : name,
      child: ClayContainer(
        variant: ClayVariant.lumen,
        // The lumen variant paints no fill of its own — without an explicit
        // colour the avatar renders as shadow only.
        color: lum.accent,
        borderRadius: size / 2,
        isDark: lum.isDark,
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials,
            style: AppTypography.label.copyWith(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Up to two initials from a full name; '?' when unknown.
  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
