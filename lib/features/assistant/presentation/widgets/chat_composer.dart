import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/voice_support.dart';

/// Chat input row: optional mic (native STT), a clay-inset multiline field, and
/// a send button. Reuses the app's existing on-device speech-to-text service.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({super.key, required this.onSend, required this.sending});

  final void Function(String text) onSend;
  final bool sending;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final VoiceInputService _voice = VoiceInputService();
  bool _listening = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.sending) return;
    widget.onSend(text);
    _controller.clear();
    _focus.requestFocus();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final result = await _voice.listen(onPartial: (p) => _controller.text = p);
    if (!mounted) return;
    setState(() => _listening = false);
    if (result != null && result.isNotEmpty) {
      _controller
        ..text = result
        ..selection = TextSelection.collapsed(offset: result.length);
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      color: lum.paper,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (voiceSearchNativeSupported) ...[
            _IconWell(
              icon: _listening ? LucideIcons.micOff : LucideIcons.mic,
              color: _listening ? lum.danger : lum.g700,
              onTap: _toggleMic,
              tooltip: _listening ? 'Stop listening' : 'Voice input',
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: ClayContainer(
              variant: ClayVariant.inset,
              color: lum.surface2,
              borderRadius: AppRadius.lg,
              isDark: lum.isDark,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: AppTypography.body.copyWith(color: lum.textPrimary),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: InputBorder.none,
                  hintText: 'Ask about your store…',
                  hintStyle: AppTypography.body.copyWith(color: lum.g400),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _IconWell(
            icon: LucideIcons.arrowUp,
            color: Colors.white,
            fill: lum.accent,
            onTap: widget.sending ? null : _submit,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

/// A 46px clay tap target. [fill] non-null → lumen gloss (send); else soft well.
class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.fill,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final Color? fill;
  final VoidCallback? onTap;

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
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: ClayContainer(
              variant: fill != null ? ClayVariant.lumen : ClayVariant.soft,
              color: fill ?? lum.surface,
              borderRadius: AppRadius.lg,
              isDark: lum.isDark,
              width: 46,
              height: 46,
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
