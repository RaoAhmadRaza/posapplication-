import 'package:flutter/material.dart';
import '../../widgets/module_scaffold.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';

/// The design's dialog layer: a centred modal on wide layouts, a bottom sheet
/// below the module breakpoint. One helper so every dialog behaves the same way
/// instead of each page rolling its own [AlertDialog]. Lifted out of the repair
/// module verbatim when settings needed the same sheet.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 420,
}) {
  final lum = context.lum;
  final isWide = ModuleScaffold.isWideOf(context);

  if (!isWide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: lum.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => Padding(
        // Keeps the sheet clear of the keyboard when it holds a form.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: lum.g300,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  builder(sheetContext),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (dialogContext) => Dialog(
      backgroundColor: lum.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: builder(dialogContext),
        ),
      ),
    ),
  );
}

/// Title + optional subtitle heading a sheet.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.title2.copyWith(
              fontSize: 19,
              color: lum.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: AppTypography.subhead.copyWith(color: lum.g500),
            ),
          ],
        ],
      ),
    );
  }
}
