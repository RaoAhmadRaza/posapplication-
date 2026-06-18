import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../domain/entities/imei_record.dart';
import '../../domain/entities/imei_status.dart';
import '../controllers/imei_controller.dart';

class ImeiLookupPage extends ConsumerStatefulWidget {
  const ImeiLookupPage({super.key});

  @override
  ConsumerState<ImeiLookupPage> createState() => _ImeiLookupPageState();
}

class _ImeiLookupPageState extends ConsumerState<ImeiLookupPage> {
  final _searchController = TextEditingController();
  List<ImeiRecord> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    await ref.read(imeiProvider.notifier).load();
    if (!mounted) return;
    final all = ref.read(imeiProvider).value ?? <ImeiRecord>[];
    setState(() {
      _results = all.where((r) => r.imei.toLowerCase().contains(q.toLowerCase())).toList();
      _searching = false;
    });
  }

  Future<void> _scanImei() async {
    final code = await scanBarcode(context, title: 'Scan IMEI');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _searchController.text = code;
    _search();
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
        title: Text('IMEI Lookup', style: AppTypography.headline),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchController,
              label: 'IMEI / Serial Number',
              prefixIcon: Icons.search,
              hint: 'Enter IMEI to lookup',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppButton(label: 'Search', onPressed: _search),
                const Spacer(),
                if (barcodeScanSupported) ...[
                  AppButton(
                    label: 'Scan',
                    variant: AppButtonVariant.tinted,
                    onPressed: _scanImei,
                    icon: Icons.qr_code_scanner,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                AppButton(
                  label: 'Load All',
                  variant: AppButtonVariant.plain,
                  onPressed: () async {
                    await ref.read(imeiProvider.notifier).load();
                    if (mounted) setState(() => _results = ref.read(imeiProvider).value ?? []);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                              const SizedBox(height: AppSpacing.md),
                              Text('No results', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
                              Text('Enter an IMEI to search or load all.', style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) => Padding(
                            padding: EdgeInsets.only(bottom: i < _results.length - 1 ? AppSpacing.sm : 0),
                            child: _ImeiCard(record: _results[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImeiCard extends StatelessWidget {
  const _ImeiCard({required this.record});
  final ImeiRecord record;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Icon(Icons.qr_code, color: AppColors.accent, size: 20)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.imei, style: AppTypography.headline),
                      const SizedBox(height: 2),
                      Text(record.sourceType, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                _ImeiStatusChip(status: record.status),
              ],
            ),
            const Divider(color: AppColors.separator, height: AppSpacing.lg),
            Row(
              children: [
                _DetailItem(label: 'Branch', value: record.branchId.substring(0, 8)),
                const SizedBox(width: AppSpacing.xl),
                _DetailItem(label: 'Cost', value: record.costPrice.toStringAsFixed(2)),
                const SizedBox(width: AppSpacing.xl),
                _DetailItem(label: 'Registered', value: _format(record.createdAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _ImeiStatusChip extends StatelessWidget {
  const _ImeiStatusChip({required this.status});
  final ImeiStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ImeiStatus.available: color = AppColors.success; break;
      case ImeiStatus.sold: color = AppColors.textPrimary; break;
      case ImeiStatus.returned: color = AppColors.warning; break;
      case ImeiStatus.transferred: color = AppColors.accent; break;
      case ImeiStatus.scrapped: color = AppColors.destructive; break;
      case ImeiStatus.reserved: color = AppColors.accent; break;
      case ImeiStatus.inTransit: color = AppColors.warning; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Text(status.dbValue, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.footnote),
      ],
    );
  }
}
