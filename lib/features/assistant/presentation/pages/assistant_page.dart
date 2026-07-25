import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../domain/entities/chat_message.dart';
import '../controllers/assistant_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_composer.dart';

/// The AI companion chat screen. The root of the `/assistant` nav-shell branch,
/// so it carries the rail/bottom bar and needs no back button of its own.
class AssistantPage extends ConsumerWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final state = ref.watch(assistantControllerProvider);
    final controller = ref.read(assistantControllerProvider.notifier);
    final messages = state.messages;

    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onHistory: () => showAppSheet<void>(
                context: context,
                builder: (_) => const _HistorySheet(),
              ),
              onNewChat: controller.startNewChat,
            ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(onPick: controller.send)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, i) =>
                          ChatBubble(message: messages[messages.length - 1 - i]),
                    ),
            ),
            if (state.toolStatus != null) _ToolStatus(name: state.toolStatus!),
            ChatComposer(onSend: controller.send, sending: state.sending),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onHistory, this.onNewChat});

  final VoidCallback? onHistory;
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LUMINA',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: lum.g400,
                  ),
                ),
                Text(
                  'Assistant',
                  style: AppTypography.title1
                      .copyWith(fontSize: 22, color: lum.textPrimary),
                ),
              ],
            ),
          ),
          if (onHistory != null) ...[
            _ClayIcon(
              icon: LucideIcons.messagesSquare,
              onTap: onHistory!,
              tooltip: 'Chat history',
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (onNewChat != null)
            _ClayIcon(
              icon: LucideIcons.squarePen,
              onTap: onNewChat!,
              tooltip: 'New chat',
            ),
        ],
      ),
    );
  }
}

class _ClayIcon extends StatelessWidget {
  const _ClayIcon({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.surface,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: lum.g600),
          ),
        ),
      ),
    );
  }
}

/// The chat-history panel: a modal (wide) / bottom sheet (narrow) of the user's
/// saved threads, newest first. Watches the controller so rename/delete update
/// live. Tapping a thread opens it; the "New" button starts a fresh chat.
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final state = ref.watch(assistantControllerProvider);
    final controller = ref.read(assistantControllerProvider.notifier);
    final convs = state.conversations;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chats',
                style: AppTypography.title2.copyWith(color: lum.textPrimary),
              ),
            ),
            AppButton(
              label: 'New',
              icon: LucideIcons.squarePen,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.tinted,
              onPressed: () {
                controller.startNewChat();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (convs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'No saved chats yet.',
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: lum.g500),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: convs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) => _ConvTile(
                conv: convs[i],
                active: convs[i].id == state.activeConversationId,
              ),
            ),
          ),
      ],
    );
  }
}

/// One thread row: title + relative time, with rename/delete actions. The whole
/// row opens the thread; the trailing icons rename or delete it.
class _ConvTile extends ConsumerWidget {
  const _ConvTile({required this.conv, required this.active});

  final ChatConversation conv;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final controller = ref.read(assistantControllerProvider.notifier);
    final title =
        (conv.title?.trim().isNotEmpty ?? false) ? conv.title!.trim() : 'New chat';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () {
          controller.openConversation(conv.id);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? lum.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.messageCircle,
                  size: 18, color: active ? lum.accent : lum.g500),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: lum.textPrimary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (conv.updatedAt != null)
                      Text(
                        _ago(conv.updatedAt!),
                        style: AppTypography.caption.copyWith(color: lum.g500),
                      ),
                  ],
                ),
              ),
              _TileIcon(
                icon: LucideIcons.pencil,
                tooltip: 'Rename',
                onTap: () => _renameConversation(context, ref, conv),
              ),
              _TileIcon(
                icon: LucideIcons.trash2,
                tooltip: 'Delete',
                onTap: () => _deleteConversation(context, ref, conv),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: lum.g500),
        ),
      ),
    );
  }
}

/// Prompt for a new title, then rename via the controller (refreshes the list).
Future<void> _renameConversation(
    BuildContext context, WidgetRef ref, ChatConversation conv) async {
  final ctrl = TextEditingController(text: conv.title ?? '');
  final save = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Rename chat',
          style: AppTypography.title2.copyWith(color: ctx.lum.textPrimary),
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: ctrl,
          label: 'Title',
          prefixIcon: LucideIcons.pencil,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: 'Save',
          fullWidth: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (save == true && context.mounted) {
    await ref
        .read(assistantControllerProvider.notifier)
        .renameConversation(conv.id, ctrl.text);
  }
  ctrl.dispose();
}

/// Confirm then delete the thread (messages cascade), with a toast.
Future<void> _deleteConversation(
    BuildContext context, WidgetRef ref, ChatConversation conv) async {
  final ok = await showAppConfirm(
    context,
    title: 'Delete chat?',
    message: 'This removes the conversation and its messages. '
        'This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await ref.read(assistantControllerProvider.notifier).deleteConversation(conv.id);
  if (context.mounted) {
    showAppToast(context, 'Chat deleted', type: BannerType.success);
  }
}

/// Compact relative time for a thread's last activity.
String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  final m = t.month.toString().padLeft(2, '0');
  final day = t.day.toString().padLeft(2, '0');
  return '${t.year}-$m-$day';
}

/// Thin "the assistant is reading your data" strip shown during a tool call.
class _ToolStatus extends StatelessWidget {
  const _ToolStatus({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(lum.g400),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Looking up your data…',
            style: AppTypography.caption.copyWith(color: lum.g500),
          ),
        ],
      ),
    );
  }
}

/// Shown before the first message: a prompt + a few tappable suggestions.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final void Function(String prompt) onPick;

  static const _suggestions = <String>[
    'How are sales today?',
    'Who owes me the most money?',
    "What's low on stock?",
    'Where do I create a purchase order?',
  ];

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClayContainer(
              variant: ClayVariant.lumen,
              color: lum.accent,
              borderRadius: AppRadius.lg,
              isDark: lum.isDark,
              width: 60,
              height: 60,
              child: const Icon(LucideIcons.sparkles, size: 28, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Ask me anything about your store',
              textAlign: TextAlign.center,
              style: AppTypography.title2.copyWith(color: lum.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sales, stock, customers, reports, or how to find things.',
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: lum.g500),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final s in _suggestions) ...[
              _SuggestionChip(text: s, onTap: () => onPick(s)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayContainer(
        variant: ClayVariant.soft,
        color: lum.surface,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.arrowUpRight, size: 16, color: lum.accent),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                style: AppTypography.body.copyWith(color: lum.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
