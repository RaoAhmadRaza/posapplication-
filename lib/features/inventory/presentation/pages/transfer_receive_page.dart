import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../domain/entities/stock_transfer_item.dart';
import '../../domain/usecases/load_transfer_items.dart';
import '../controllers/transfers_controller.dart';
import '../widgets/inventory_ui.dart';

class TransferReceivePage extends ConsumerStatefulWidget {
  const TransferReceivePage({super.key, required this.transferId});

  final String transferId;

  @override
  ConsumerState<TransferReceivePage> createState() => _TransferReceivePageState();
}

class _TransferReceivePageState extends ConsumerState<TransferReceivePage> {
  List<StockTransferItem>? _items;
  final Map<String, TextEditingController> _controllers = {};
  String? _error;
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final (items, failure) = await ref.read(loadTransferItemsUseCaseProvider).call(widget.transferId);
    if (!mounted) return;
    if (failure != null) {
      setState(() { _loading = false; _error = failure.message; });
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
      for (final item in items) {
        final remaining = item.qty - item.qtyReceived;
        if (remaining > 0) {
          _controllers[item.id] = TextEditingController(text: remaining.toString());
        }
      }
    });
  }

  /// A line contributes when its entered quantity is above zero and within the
  /// outstanding remainder — mirrors the same clamp used by [_receive].
  bool get _canReceive {
    for (final item in _items ?? <StockTransferItem>[]) {
      final ctrl = _controllers[item.id];
      if (ctrl == null) continue;
      final qty = double.tryParse(ctrl.text.trim()) ?? 0;
      if (qty > 0 && qty <= item.qty - item.qtyReceived) return true;
    }
    return false;
  }

  Future<void> _receive() async {
    final received = <Map<String, dynamic>>[];
    for (final item in _items ?? <StockTransferItem>[]) {
      final ctrl = _controllers[item.id];
      if (ctrl == null) continue;
      final qty = double.tryParse(ctrl.text.trim()) ?? 0;
      if (qty > 0 && qty <= item.qty - item.qtyReceived) {
        received.add({'item_id': item.id, 'qty_received': qty});
      }
    }
    if (received.isEmpty) {
      setState(() => _error = 'Enter at least one valid receive quantity.');
      return;
    }

    setState(() { _posting = true; _error = null; });
    await ref.read(transfersProvider.notifier).receive(widget.transferId, received);
    if (!mounted) return;
    showAppToast(context, 'Stock received');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Receive transfer',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton();

    if (_error != null && _items == null) {
      return AppErrorState(
        title: "Unable to load this transfer",
        body: _error!,
        onRetry: _load,
      );
    }

    final items = _items ?? <StockTransferItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          AppInlineBanner(message: _error!, type: BannerType.error),
          const SizedBox(height: 16),
        ],
        for (final item in items) ...[
          _ReceiveLineCard(
            item: item,
            controller: _controllers[item.id],
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        AppButton(
          label: 'Receive stock',
          icon: LucideIcons.packageCheck,
          loading: _posting,
          fullWidth: true,
          onPressed: _canReceive ? _receive : null,
        ),
      ],
    );
  }
}

class _ReceiveLineCard extends StatelessWidget {
  const _ReceiveLineCard({
    required this.item,
    required this.controller,
    required this.onChanged,
  });

  final StockTransferItem item;
  final TextEditingController? controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final sent = item.qty;
    final alreadyReceived = item.qtyReceived;
    final remaining = sent - alreadyReceived;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayContainer(
                variant: ClayVariant.inset,
                color: lum.g100,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 42,
                height: 42,
                child: Icon(kInvItemIcon, size: 20, color: lum.g500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Item ${item.productId.substring(0, 8)}…',
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatTile(label: 'Sent', value: qtyLabel(sent)),
              const SizedBox(width: 10),
              _StatTile(label: 'Received', value: qtyLabel(alreadyReceived)),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Remaining',
                value: qtyLabel(remaining),
                valueColor: remaining > 0 ? lum.warningText : null,
              ),
            ],
          ),
          if (controller != null && remaining > 0) ...[
            const SizedBox(height: 14),
            AppTextField(
              controller: controller!,
              label: 'Quantity to receive',
              prefixIcon: LucideIcons.packageCheck,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              hint: 'Up to ${qtyLabel(remaining)}',
              onChanged: (_) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Expanded(
      child: ClayContainer(
        variant: ClayVariant.inset,
        color: lum.g100,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: lum.g400,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.headline.copyWith(
                color: valueColor ?? lum.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
