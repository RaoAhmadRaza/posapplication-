import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/import_result.dart';

/// Lucide glyph per import step (matches the design export's icon choices).
IconData migrationKindIcon(ImportTableKind kind) => switch (kind) {
      ImportTableKind.categories => LucideIcons.tag,
      ImportTableKind.brands => LucideIcons.bookmark,
      ImportTableKind.products => LucideIcons.box,
      ImportTableKind.stock => LucideIcons.layers,
    };

/// Split a controller log line ("HH:MM:SS.mmm message") into (time, message).
/// The controller timestamps every line with a fixed-width prefix; this only
/// separates it for display — it never infers tone from the text.
(String time, String message) splitLogLine(String line) {
  final i = line.indexOf(' ');
  if (i < 0) return ('', line);
  return (line.substring(0, i), line.substring(i + 1));
}
