import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/stock_transfer_item.dart';
import '../../domain/usecases/load_transfer_items.dart';
import '../controllers/transfers_controller.dart';

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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Receive Transfer', style: AppTypography.headline),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppInlineBanner(message: _error!, type: BannerType.error),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        if (_error != null) ...[
                          AppInlineBanner(message: _error!, type: BannerType.error),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        ..._items!.map((item) {
                          final sent = item.qty;
                          final alreadyReceived = item.qtyReceived;
                          final remaining = sent - alreadyReceived;
                          final ctrl = _controllers[item.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.inventory_2, size: 18, color: AppColors.accent),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Item ${item.productId.substring(0, 8)}...', style: AppTypography.body),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  _MetricLabel(label: 'Sent', value: sent.toString()),
                                                  const SizedBox(width: AppSpacing.lg),
                                                  _MetricLabel(label: 'Received', value: alreadyReceived.toString()),
                                                  const SizedBox(width: AppSpacing.lg),
                                                  _MetricLabel(label: 'Remaining', value: remaining.toString(), accent: remaining > 0),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (ctrl != null && remaining > 0) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      AppTextField(
                                        controller: ctrl,
                                        label: 'Quantity to Receive',
                                        prefixIcon: Icons.download_done,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        hint: 'Up to $remaining',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Receive Stock',
                          loading: _posting,
                          onPressed: _receive,
                          fullWidth: true,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel({required this.label, required this.value, this.accent = false});
  final String label, value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.headline.copyWith(color: accent ? AppColors.accent : AppColors.textPrimary)),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
      ],
    );
  }
}
