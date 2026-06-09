import 'package:flutter/widgets.dart';
import 'breakpoints.dart';

extension ResponsiveExtension on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < kMobileBreakpoint;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= kMobileBreakpoint &&
      MediaQuery.of(this).size.width < kTabletBreakpoint;
  bool get isDesktop => MediaQuery.of(this).size.width >= kTabletBreakpoint;
}
