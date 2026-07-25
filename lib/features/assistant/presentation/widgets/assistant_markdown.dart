import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';

/// Minimal markdown renderer for assistant replies — no dependency. Handles the
/// subset LLMs actually emit: `#`/`##`/`###` headings, `**bold**`, `` `code` ``,
/// `-`/`*` bullets, `1.` numbered lists, GFM pipe tables, and blank lines as
/// paragraph gaps. Wrapped in a SelectionArea so the whole answer stays copyable.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text});

  final String text;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+?)`');
  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)\.\s+(.*)$');
  static final _divider = RegExp(r'^:?-{1,}:?$');

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final base = AppTypography.body.copyWith(color: lum.textPrimary, height: 1.42);

    final children = <Widget>[];
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();

      // A GFM table: a run of `|`-rows whose 2nd row is the `|---|` divider.
      // Anything shorter (a lone `| foo` line) falls through to plain text.
      if (_isTableRow(line)) {
        final block = <String>[];
        while (i < lines.length && _isTableRow(lines[i].trimRight())) {
          block.add(lines[i].trimRight());
          i++;
        }
        if (block.length >= 2 && _isDivider(block[1])) {
          children.add(_table(block, base, lum));
          continue;
        }
        for (final l in block) {
          children.add(Text.rich(TextSpan(children: _spans(l, base, lum)), style: base));
        }
        continue;
      }

      i++;

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

  /// Whether [line] is a pipe-table row (after trimming, starts with `|`).
  bool _isTableRow(String line) => line.trim().startsWith('|');

  /// Whether every cell of [line] is a `---`/`:--:` divider cell.
  bool _isDivider(String line) {
    final cells = _cells(line);
    return cells.isNotEmpty && cells.every((c) => _divider.hasMatch(c));
  }

  /// Split a pipe row into trimmed cells, dropping the outer pipes.
  List<String> _cells(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((c) => c.trim()).toList();
  }

  /// Render a GFM table block (header row, `---` divider, body rows) as a real
  /// [Table]. Rows are normalised to the header's column count so a ragged LLM
  /// row can't crash Table's equal-length requirement.
  Widget _table(List<String> block, TextStyle base, LumColors lum) {
    final dataRows = [for (final l in block) if (!_isDivider(l)) _cells(l)];
    if (dataRows.isEmpty) return const SizedBox.shrink();
    final colCount = dataRows.first.length;

    List<Widget> cellsFor(List<String> cells, {required bool header}) {
      final style = header ? base.copyWith(fontWeight: FontWeight.w700) : base;
      return [
        for (var c = 0; c < colCount; c++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text.rich(
              TextSpan(
                children: _spans(c < cells.length ? cells[c] : '', style, lum),
              ),
              style: style,
            ),
          ),
      ];
    }

    final rows = <TableRow>[
      for (var r = 0; r < dataRows.length; r++)
        TableRow(
          decoration: r == 0 ? BoxDecoration(color: lum.surface2) : null,
          children: cellsFor(dataRows[r], header: r == 0),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
          border: TableBorder.all(color: lum.hairline, width: 1),
          defaultColumnWidth: const FlexColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        ),
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
