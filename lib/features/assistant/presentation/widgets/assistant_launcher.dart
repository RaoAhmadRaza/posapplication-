import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/clay.dart';

/// Global AI-assistant launcher. Drop into any header `actions` row (beside the
/// notification bell). Clay-inset well, matching NotificationBell's chrome.
class AssistantLauncher extends StatelessWidget {
  const AssistantLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Tooltip(
      message: 'Assistant',
      child: Semantics(
        button: true,
        label: 'Open the AI assistant',
        child: InkWell(
          onTap: () => context.push('/assistant'),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.sm,
            width: 40,
            height: 40,
            isDark: lum.isDark,
            child: Center(
              child: Icon(LucideIcons.sparkles, size: 20, color: lum.g700),
            ),
          ),
        ),
      ),
    );
  }
}
