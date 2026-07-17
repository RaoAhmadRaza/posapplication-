import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/staff_entities.dart';
import '../../domain/failures/staff_failure.dart';
import '../controllers/staff_controllers.dart';

class StaffInvitesPage extends ConsumerWidget {
  const StaffInvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invitesControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Staff', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'users',
        action: 'create',
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/staff/invite'),
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.person_add_alt, color: Colors.white),
          label: const Text('Invite', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(invitesControllerProvider.notifier).refresh(),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: AppInlineBanner(
                  message: e is StaffFailure ? e.message : 'Could not load invites.',
                  type: BannerType.error,
                ),
              ),
            ]),
            data: (rows) {
              if (rows.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text('No staff invites yet.',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                children: [
                  for (final inv in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _InviteCard(invite: inv),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});
  final StaffInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = invite.fullName?.isNotEmpty == true
        ? invite.fullName!
        : (invite.email ?? 'Invited staff');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.body),
                    const SizedBox(height: 2),
                    Text('${invite.roleName} · ${invite.branchNames.join(", ")}',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              _StatusChip(status: invite.effectiveStatus),
              _InviteMenu(invite: invite),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteMenu extends ConsumerWidget {
  const _InviteMenu({required this.invite});
  final StaffInvite invite;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<StaffFailure?> Function() action) async {
    final result = await action();
    if (!context.mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(staffActionsProvider);
    final items = <PopupMenuEntry<String>>[];
    if (invite.isPending) {
      items.add(const PopupMenuItem(value: 'regenerate', child: Text('Regenerate QR')));
      items.add(const PopupMenuItem(value: 'revoke', child: Text('Revoke')));
    }
    if (invite.isAwaitingConfirmation) {
      items.add(const PopupMenuItem(value: 'release', child: Text('Release & re-invite')));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return PermissionGate(
      module: 'users',
      action: 'update',
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
        itemBuilder: (_) => items,
        onSelected: (v) async {
          switch (v) {
            case 'regenerate':
              final (created, f) = await actions.regenerateInvite(invite.id);
              if (!context.mounted) return;
              if (f != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(f.message)));
              } else if (created != null) {
                context.push('/staff/invite/${created.inviteId}/qr', extra: created);
              }
            case 'revoke':
              await _run(context, ref, () => actions.revokeInvite(invite.id));
            case 'release':
              await _run(context, ref, () => actions.releaseAbandoned(invite.id));
          }
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PENDING' => ('Pending', AppColors.accent),
      'AWAITING_CONFIRMATION' => ('Awaiting email', AppColors.warning),
      'REDEEMED' => ('Active', AppColors.success),
      'EXPIRED' => ('Expired', AppColors.textMuted),
      'REVOKED' => ('Revoked', AppColors.textMuted),
      _ => (status, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(
              color: color, fontWeight: FontWeight.w600)),
    );
  }
}
