import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_radius.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/design/format.dart';
import '../../../../../core/design/widgets/app_pill.dart';
import '../../../domain/entities/cashier_session.dart';
import '../../controllers/session_sales_provider.dart';

/// Slim strip under the header showing the open register: how long it has been
/// open, a staleness warning, and the live session total.
class PosSessionBanner extends ConsumerWidget {
  const PosSessionBanner({super.key, required this.session});

  final CashierSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final isStale =
        DateTime.now().difference(session.openedAt).inHours > 12;
    final salesAsync = ref.watch(sessionSalesProvider(session.id));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isStale ? lum.warningSoft : lum.surface,
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Icon(
            isStale ? LucideIcons.triangleAlert : LucideIcons.lockOpen,
            size: 15,
            color: isStale ? lum.warningText : lum.g500,
          ),
          const SizedBox(width: 8),
          Text(
            'Open ${_relativeTime(session.openedAt)}',
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              color: isStale ? lum.warningText : lum.g500,
            ),
          ),
          if (isStale) ...[
            const SizedBox(width: 8),
            const AppPill(label: 'Stale', tone: AppPillTone.warning),
          ],
          const Spacer(),
          Text(
            salesAsync.when(
              data: (v) => 'Sales ${formatPkr(v)}',
              loading: () => 'Sales …',
              error: (_, _) => 'Sales —',
            ),
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: salesAsync.hasError ? lum.dangerText : lum.accentPress,
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

/// Dismissible notice that a cart was auto-saved when the app went to the
/// background.
class PosAutoSavedNote extends StatelessWidget {
  const PosAutoSavedNote({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: lum.successSoft,
      child: Row(
        children: [
          Icon(LucideIcons.save, size: 15, color: lum.successText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-saved cart available — open Held to restore it.',
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: lum.successText,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Dismiss',
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(LucideIcons.x, size: 14, color: lum.successText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
