import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../controllers/assistant_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_composer.dart';

/// The AI companion chat screen. A pushed top-level route (`/assistant`).
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
              onBack: () => Navigator.of(context).maybePop(),
              onReset: messages.isEmpty ? null : controller.reset,
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
  const _Header({required this.onBack, this.onReset});

  final VoidCallback onBack;
  final VoidCallback? onReset;

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
          _ClayIcon(icon: LucideIcons.arrowLeft, onTap: onBack, tooltip: 'Back'),
          const SizedBox(width: AppSpacing.md),
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
          if (onReset != null)
            _ClayIcon(
              icon: LucideIcons.squarePen,
              onTap: onReset!,
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
