import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/voice_support.dart';
import '../../../../core/services/voxa_stt_service.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../inventory/domain/usecases/search_products.dart';
import '../../../assistant/presentation/widgets/assistant_launcher.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../search/presentation/widgets/global_search_field.dart';
import '../../../sync/presentation/widgets/sync_status_widget.dart';
import '../controllers/dashboard_controller.dart';
import '../pages/dashboard_page.dart' show dashboardEditingProvider;

/// Lets the app-level CMD+K shortcut focus the header search field.
final searchFieldKey = GlobalKey<GlobalSearchFieldState>();

/// Dashboard header: title plus edit-layout, refresh, notifications and (wide
/// only) sync status. Bespoke rather than a Material AppBar so the LUMINA
/// heights (60 wide / 52 narrow) and square icon buttons are exact.
class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const DashboardAppBar({super.key, required this.isWide});

  final bool isWide;

  @override
  Size get preferredSize => Size.fromHeight(isWide ? 60 : 52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final editing = ref.watch(dashboardEditingProvider);
    final loading = ref.watch(dashboardProvider).isLoading;

    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.only(left: isWide ? 24 : 18, right: isWide ? 24 : 8),
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Dashboard',
              style: AppTypography.title1.copyWith(
                fontSize: isWide ? 22 : 21,
                color: lum.textPrimary,
              ),
            ),
          ),
          if (isWide) ...[
            GlobalSearchField(key: searchFieldKey),
            const SizedBox(width: 16),
          ],
          if (isWide && voiceSearchSupported) const _DashboardVoiceButton(),
          if (barcodeScanSupported || barcodeImageScanSupported)
            HeaderIconButton(
              icon: LucideIcons.qrCode,
              iconSize: isWide ? 20 : 21,
              tooltip: 'Scan product',
              onPressed: () => _scanAndJump(context, ref),
            ),
          HeaderIconButton(
            icon: editing ? LucideIcons.check : LucideIcons.slidersHorizontal,
            iconSize: isWide ? 20 : 21,
            tooltip: editing ? 'Done' : 'Edit layout',
            active: editing,
            onPressed: () =>
                ref.read(dashboardEditingProvider.notifier).toggle(),
          ),
          _RefreshButton(
            spinning: loading,
            iconSize: isWide ? 19 : 20,
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
          const AssistantLauncher(),
          const NotificationBell(),
          if (isWide) ...[
            const SizedBox(width: 8),
            const SyncStatusWidget(),
          ],
        ],
      ),
    );
  }
}

/// 40x40 square header action. Filled with the accent tint when [active].
/// [spin] rotates the icon only, leaving the hit box steady.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = 20,
    this.active = false,
    this.spin,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;
  final bool active;
  final Animation<double>? spin;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    Widget glyph = Icon(
      icon,
      size: iconSize,
      color: active ? lum.accent : lum.g600,
    );
    if (spin != null) {
      glyph = RotationTransition(turns: spin!, child: glyph);
    }

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? lum.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: glyph,
          ),
        ),
      ),
    );
  }
}

/// Refresh action whose icon spins while the dashboard is loading. Falls back
/// to a static icon when the OS asks for reduced motion.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({
    required this.spinning,
    required this.onPressed,
    required this.iconSize,
  });

  final bool spinning;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  void _syncSpin() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.spinning && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HeaderIconButton(
      icon: LucideIcons.refreshCw,
      iconSize: widget.iconSize,
      tooltip: 'Refresh',
      onPressed: widget.onPressed,
      spin: _controller,
    );
  }
}

/// Dashboard header scan: decode a product code (camera/image), then jump to
/// that product's stock detail on a single exact match, else report no match.
Future<void> _scanAndJump(BuildContext context, WidgetRef ref) async {
  final code = await scanProductCode(context);
  if (!context.mounted || code == null) return;
  if (code == barcodeNoCodeFoundSentinel) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No barcode or QR found in that image')),
    );
    return;
  }
  final (results, failure) =
      await ref.read(searchProductsUseCaseProvider).call(code);
  if (!context.mounted) return;
  if (failure == null) {
    final exact =
        results.where((p) => p.barcode == code || p.sku == code).toList();
    if (exact.length == 1) {
      context.push('/inventory/stock/${exact.first.id}');
      return;
    }
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No product matches that code')),
  );
}

/// Header voice search (native speech_to_text): dictates into the global search
/// field. Shown only when wide (where the search field is mounted) and voice is
/// natively supported.
class _DashboardVoiceButton extends StatefulWidget {
  const _DashboardVoiceButton();

  @override
  State<_DashboardVoiceButton> createState() => _DashboardVoiceButtonState();
}

class _DashboardVoiceButtonState extends State<_DashboardVoiceButton> {
  final _voice = VoiceInputService();
  bool _listening = false;

  @override
  void dispose() {
    _voice.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    // Windows/Linux: record → Voxa transcribe on the second tap.
    if (voiceSearchCloudSupported) {
      if (VoxaStt.instance.isRecording) {
        final text = await VoxaStt.instance.stopAndTranscribe();
        if (!mounted) return;
        setState(() => _listening = false);
        if (text != null) {
          searchFieldKey.currentState?.setQuery(text);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voice service unavailable — is Voxa running?'),
          ));
        }
        return;
      }
      final ok = await VoxaStt.instance.startRecording();
      if (!mounted) return;
      setState(() => _listening = ok);
      return;
    }
    if (_listening) {
      _voice.cancel();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final result = await _voice.listen(
      onPartial: (p) {
        if (mounted) searchFieldKey.currentState?.setQuery(p);
      },
    );
    if (!mounted) return;
    setState(() => _listening = false);
    if (result != null && result.isNotEmpty) {
      searchFieldKey.currentState?.setQuery(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeaderIconButton(
      icon: _listening ? LucideIcons.mic : LucideIcons.micOff,
      tooltip: 'Voice search',
      active: _listening,
      onPressed: _toggle,
    );
  }
}
