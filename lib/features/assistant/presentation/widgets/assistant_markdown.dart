import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';

/// Minimal markdown renderer for assistant replies — no dependency. Handles the
/// subset LLMs actually emit: `#`/`##`/`###` headings, `**bold**`, `` `code` ``,
/// `-`/`*` bullets, and `1.` numbered lists, with blank lines as paragraph gaps.
/// Wrapped in a SelectionArea so the whole answer stays copyable.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text});

  final String text;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+?)`');
  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)\.\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final base = AppTypography.body.copyWith(color: lum.textPrimary, height: 1.42);

    final children = <Widget>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();

      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: AppSpacing.sm));
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = switch (level) { 1 => 20.0, 2 => 17.0, _ => 15.5 };
        children.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 2),
          child: Text.rich(
            TextSpan(children: _spans(heading.group(2)!, base, lum)),
            style: base.copyWith(fontSize: size, fontWeight: FontWeight.w700),
          ),
        ));
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        children.add(_listRow('•  ', bullet.group(1)!, base, lum));
        continue;
      }

      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        children.add(_listRow('${numbered.group(1)}.  ', numbered.group(2)!, base, lum));
        continue;
      }

      children.add(Text.rich(TextSpan(children: _spans(line, base, lum)), style: base));
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _listRow(String marker, String content, TextStyle base, LumColors lum) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(marker, style: base),
          Expanded(
            child: Text.rich(TextSpan(children: _spans(content, base, lum)), style: base),
          ),
        ],
      ),
    );
  }

  /// Inline parse: `**bold**` and `` `code` ``; everything else is plain.
  List<InlineSpan> _spans(String s, TextStyle base, LumColors lum) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: lum.surface2,
            color: lum.textPrimary,
          ),
        ));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }
}
