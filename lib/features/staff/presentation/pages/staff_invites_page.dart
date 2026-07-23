import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/staff_entities.dart';
import '../../domain/failures/staff_failure.dart';
import '../controllers/staff_controllers.dart';
import '../widgets/staff_invite_card.dart';

class StaffInvitesPage extends ConsumerWidget {
  const StaffInvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invitesControllerProvider);
    return AppDetailScaffold(
      eyebrow: 'Staff',
      title: 'Staff invites',
      description: 'Send someone a one-time code to join. '
          'Codes expire automatically — regenerate any pending one from its menu.',
      actions: [
        PermissionGate(
          module: 'users',
          action: 'create',
          child: AppButton(
            label: 'Invite',
            size: AppButtonSize.sm,
            icon: LucideIcons.userPlus,
            onPressed: () => context.push('/staff/invite'),
          ),
        ),
      ],
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppErrorState(
          title: "Couldn't load invites",
          body: e is StaffFailure ? e.message : 'Please try again.',
          onRetry: () => ref.read(invitesControllerProvider.notifier).refresh(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.userPlus,
              title: 'No invites yet',
              body: 'Invite your first teammate and their access will show up '
                  'here — pending, redeemed or expired at a glance.',
              action: PermissionGate(
                module: 'users',
                action: 'create',
                child: AppButton(
                  label: 'Invite someone',
                  icon: LucideIcons.userPlus,
                  onPressed: () => context.push('/staff/invite'),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final inv in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaffInviteCard(
                    invite: inv,
                    menu: _InviteMenu(invite: inv),
                  ),
                ),
            ],
          );
        },
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
    final lum = context.lum;
    final actions = ref.read(staffActionsProvider);
    final items = <PopupMenuEntry<String>>[];
    if (invite.isPending) {
      items.add(const PopupMenuItem(value: 'regenerate', child: Text('Regenerate QR code')));
      items.add(const PopupMenuItem(value: 'revoke', child: Text('Revoke invite')));
    }
    if (invite.isAwaitingConfirmation) {
      items.add(const PopupMenuItem(value: 'release', child: Text('Release & re-invite')));
    }
    if (items.isEmpty) return const SizedBox(width: 4);
    return PermissionGate(
      module: 'users',
      action: 'update',
      child: PopupMenuButton<String>(
        icon: Icon(LucideIcons.ellipsisVertical, color: lum.g500, size: 20),
        tooltip: 'Invite actions',
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
