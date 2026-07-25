import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_hover.dart';
import '../../domain/entities/drilldown.dart';
import '../controllers/drilldown_controller.dart';
import '../widgets/dashboard_layout.dart';

class DrilldownPage extends ConsumerWidget {
  const DrilldownPage({super.key, required this.args, required this.title});

  final DrilldownArgs args;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final metrics = DashboardMetrics.of(context);
    final state = ref.watch(drilldownProvider(args));

    return Scaffold(
      backgroundColor: lum.paper,
      appBar: _DrilldownAppBar(title: title, isWide: metrics.isWide),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.maxWidth),
            child: state.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: lum.accent),
              ),
              error: (_, _) => _EmptyState(
                icon: LucideIcons.cloudOff,
                message: "Couldn't load this list",
                action: AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(drilldownProvider(args)),
                  variant: AppButtonVariant.plain,
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const _EmptyState(
                    icon: LucideIcons.inbox,
                    message: 'Nothing to show',
                  );
                }
                return ListView(
                  padding: metrics.pad,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
                      child: Text(
                        '${rows.length} RESULTS',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: lum.g500,
                        ),
                      ),
                    ),
                    ClayContainer(
                      variant: ClayVariant.soft,
                      color: lum.surface,
                      borderRadius: AppRadius.lg,
                      isDark: lum.isDark,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++)
                              _DrilldownRowTile(row: rows[i], first: i == 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DrilldownAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DrilldownAppBar({required this.title, required this.isWide});

  final String title;
  final bool isWide;

  @override
  Size get preferredSize => Size.fromHeight(isWide ? 60 : 52);

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12),
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: AppHover(
              radius: AppRadius.sm,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: isWide ? 22 : 24,
                    color: lum.accent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title1.copyWith(
                fontSize: isWide ? 22 : 19,
                color: lum.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrilldownRowTile extends StatelessWidget {
  const _DrilldownRowTile({required this.row, required this.first});

  final DrilldownRow row;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // `trailing` arrives pre-formatted; a leading minus is the only signal that
    // the amount is negative.
    final negative = row.trailing.contains('-');

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: lum.textPrimary,
                  ),
                ),
                if (row.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 12,
                      color: lum.g500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 11),
          Text(
            row.trailing,
            style: AppTypography.monoValue.copyWith(
              fontSize: 13,
              color: negative ? lum.dangerText : lum.textPrimary,
            ),
          ),
          if (row.deepLink != null) ...[
            const SizedBox(width: 11),
            Icon(LucideIcons.chevronRight, size: 17, color: lum.g400),
          ],
        ],
      ),
    );

    if (row.deepLink == null) return tile;
    return AppHover(
      radius: 0,
      child: InkWell(onTap: () => context.push(row.deepLink!), child: tile),
    );
  }
}

/// Shared empty/error presentation for the drilldown list.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: lum.g400),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: lum.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
