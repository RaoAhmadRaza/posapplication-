import '../../../../core/widgets/module_scaffold.dart';

/// The sales chrome now lives in `core/widgets/module_scaffold.dart`, shared
/// with repair. These aliases keep every sales page compiling unchanged.
typedef SalesScaffold = ModuleScaffold;
typedef SalesHeader = ModuleHeader;
typedef SalesAvatar = ModuleAvatar;

/// Width at or above which sales screens use their wide layout.
const kSalesWideBreakpoint = kModuleWideBreakpoint;
