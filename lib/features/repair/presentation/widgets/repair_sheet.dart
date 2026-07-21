import 'package:flutter/material.dart';
import '../../../../core/design/widgets/app_sheet.dart';

/// The sheet helper moved to the design system when settings needed it too.
/// These aliases keep every repair call site compiling unchanged.
Future<T?> showRepairSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 420,
}) =>
    showAppSheet<T>(context: context, builder: builder, width: width);

typedef RepairSheetHeader = AppSheetHeader;
