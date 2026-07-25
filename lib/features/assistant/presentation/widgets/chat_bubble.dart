import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../domain/entities/chat_message.dart';
import 'assistant_markdown.dart';

/// A single chat turn. User bubbles align right (accent-soft); assistant bubbles
/// align left (surface-2) behind a small avatar, so the thread reads as a chat.
/// An empty assistant bubble renders a typing indicator.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isUser = message.role == ChatRole.user;
    final isEmptyAssistant = !isUser && message.content.isEmpty;

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isUser ? lum.accentSoft : lum.surface2,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.sm),
          bottomRight: Radius.circular(isUser ? AppRadius.sm : AppRadius.lg),
        ),
      ),
      child: isEmptyAssistant
          ? _TypingDot(color: lum.g500)
          : isUser
              ? SelectableText(
                  message.content,
                  style: AppTypography.body.copyWith(
                    color: lum.textPrimary,
                    height: 1.42,
                  ),
                )
              : AssistantMarkdown(text: message.content),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: isUser
          ? Align(alignment: Alignment.centerRight, child: bubble)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(lum: lum),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: bubble),
              ],
            ),
    );
  }
}

/// The assistant's identity mark beside its replies.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.lum});

  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      variant: ClayVariant.lumen,
      color: lum.accent,
      borderRadius: 15,
      isDark: lum.isDark,
      width: 30,
      height: 30,
      child: const Icon(LucideIcons.sparkles, size: 15, color: Colors.white),
    );
  }
}

/// Minimal "thinking" indicator shown while the first token is pending.
class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
