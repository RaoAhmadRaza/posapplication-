import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/chat_message.dart';
import 'assistant_markdown.dart';

/// A single chat turn. User bubbles align right (accent-soft), assistant bubbles
/// align left (surface-2). An empty assistant bubble renders a typing indicator.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isUser = message.role == ChatRole.user;
    final isEmptyAssistant = !isUser && message.content.isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
      ),
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
