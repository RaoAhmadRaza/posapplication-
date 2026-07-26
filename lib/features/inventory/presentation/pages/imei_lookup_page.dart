import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../domain/entities/imei_record.dart';
import '../../domain/entities/product.dart';
import '../controllers/imei_controller.dart';
import '../controllers/products_controller.dart';
import '../widgets/inventory_ui.dart';

class ImeiLookupPage extends ConsumerStatefulWidget {
  const ImeiLookupPage({super.key});

  @override
  ConsumerState<ImeiLookupPage> createState() => _ImeiLookupPageState();
}

class _ImeiLookupPageState extends ConsumerState<ImeiLookupPage> {
  final _searchController = TextEditingController();
  List<ImeiRecord> _results = [];
  bool _searching = false;
  bool _searched = false;
  bool _error = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = false;
    });
    await ref.read(imeiProvider.notifier).load();
    if (!mounted) return;
    final snapshot = ref.read(imeiProvider);
    final all = snapshot.value ?? <ImeiRecord>[];
    setState(() {
      _results =
          all.where((r) => r.imei.toLowerCase().contains(q.toLowerCase())).toList();
      _searched = true;
      _error = snapshot.hasError;
      _searching = false;
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _searching = true;
      _error = false;
    });
    await ref.read(imeiProvider.notifier).load();
    if (!mounted) return;
    final snapshot = ref.read(imeiProvider);
    setState(() {
      _results = snapshot.value ?? <ImeiRecord>[];
      _searched = true;
      _error = snapshot.hasError;
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
    final lum = context.lum;

    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Column(
          children: [
            _header(lum),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppSearchField(
                          controller: _searchController,
                          hint: 'Enter IMEI or serial',
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      if (barcodeScanSupported) ...[
                        const SizedBox(width: 10),
                        _ToolIcon(
                          icon: LucideIcons.scanLine,
                          tooltip: 'Scan IMEI',
                          onTap: _scanImei,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Search',
                          icon: LucideIcons.search,
                          onPressed: _search,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: 'Load all',
                        variant: AppButtonVariant.tinted,
                        onPressed: _loadAll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(lum)),
          ],
        ),
      ),
    );
  }

  Widget _header(LumColors lum) {
    final back = Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          back,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'INVENTORY',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: lum.g400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'IMEI lookup',
                  style: AppTypography.title1
                      .copyWith(fontSize: 23, color: lum.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LumColors lum) {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: AppListSkeleton(),
      );
    }
    if (_error) {
      return AppErrorState(
        title: "Unable to run the lookup",
        body: 'Unable to reach the server. Try again in a moment.',
        onRetry: _searchController.text.trim().isEmpty ? _loadAll : _search,
      );
    }
    if (_results.isEmpty) {
      return AppEmptyState(
        icon: LucideIcons.searchCode,
        title: _searched ? 'No matches' : 'Search for a device',
        body: _searched
            ? 'No IMEI or serial matches that search. Check the number '
                'and try again.'
            : 'Enter an IMEI or serial number, or load all to browse '
                'registered devices.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: i < _results.length - 1 ? 10 : 0),
        child: _ImeiCard(record: _results[i]),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.surface,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(icon, size: 19, color: lum.g600),
          ),
        ),
      ),
    );
  }
}

class _ImeiCard extends ConsumerWidget {
  const _ImeiCard({required this.record});

  final ImeiRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final productName =
        products.where((p) => p.id == record.productId).firstOrNull?.name;
    final (tone, label) = imeiStatusPill(record.status);

    return AppCard(
      padding: const EdgeInsets.all(14),
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
                width: 46,
                height: 46,
                child: Icon(kInvItemIcon, size: 21, color: lum.g500),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.imei,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.monoValue.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: lum.textPrimary,
                      ),
                    ),
                    if (productName != null && productName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: lum.g500, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppPill(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: lum.hairline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              _metaCell(
                lum,
                'Branch',
                Text(
                  record.branchId.length >= 8
                      ? record.branchId.substring(0, 8)
                      : record.branchId,
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 13, color: lum.g600),
                ),
              ),
              _metaCell(
                lum,
                'Source',
                Text(
                  record.sourceType,
                  style: AppTypography.footnote.copyWith(color: lum.g600),
                ),
              ),
              _metaCell(
                lum,
                'Since',
                Text(
                  ymd(record.createdAt),
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 13, color: lum.g600),
                ),
              ),
              _metaCell(lum, 'Cost', AppMoneyText(record.costPrice, size: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaCell(LumColors lum, String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: lum.g400,
            ),
          ),
          const SizedBox(height: 3),
          value,
        ],
      );
}
