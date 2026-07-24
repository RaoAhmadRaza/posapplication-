import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../controllers/global_search_controller.dart';

/// Matches the debounce every other search field in the app uses.
const _kDebounce = Duration(milliseconds: 300);

/// Header search box that drops a results panel beneath itself.
///
/// Wide layouts only — the design has no search on the mobile app bar.
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key, this.width = 220});

  final double width;

  @override
  ConsumerState<GlobalSearchField> createState() => GlobalSearchFieldState();
}

class GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _link = LayerLink();
  Timer? _debounce;
  OverlayEntry? _overlay;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Focuses the field and selects any existing text — the CMD+K entry point.
  void focusSearch() {
    _focusNode.requestFocus();
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  /// Sets the query text (e.g. from voice search) and opens the results.
  void setQuery(String text) {
    _controller.text = text;
    _focusNode.requestFocus();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      if (!mounted) return;
      setState(() => _query = _controller.text);
      _syncOverlay();
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _syncOverlay();
    } else {
      // Let a tap on a result land before the panel goes away.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _syncOverlay() {
    final shouldShow = _focusNode.hasFocus && _query.trim().length >= 2;
    if (!shouldShow) {
      _removeOverlay();
      return;
    }
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: _buildPanel);
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _dismiss() {
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _openHit(SearchHit hit) {
    _controller.clear();
    _dismiss();
    // Customer hits land in a nav-shell branch; go switches to it (a push from
    // the shell chrome would duplicate the shell page key). Product/invoice
    // hits are top-level pages and push cleanly.
    if (hit.route.startsWith('/customers')) {
      context.go(hit.route);
    } else {
      context.push(hit.route);
    }
  }

  Widget _buildPanel(BuildContext overlayContext) {
    return Positioned(
      width: 360,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: _ResultsPanel(query: _query, onSelect: _openHit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hintShortcut = _shortcutHint();

    return CompositedTransformTarget(
      link: _link,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
        },
        child: ClayContainer(
          variant: ClayVariant.inset,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          width: widget.width,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 17, color: lum.g400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: AppTypography.footnote.copyWith(
                    fontSize: 13,
                    color: lum.textPrimary,
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search…',
                    hintStyle: AppTypography.footnote.copyWith(
                      fontSize: 13,
                      color: lum.g400,
                    ),
                  ),
                ),
              ),
              if (_controller.text.isEmpty)
                Text(
                  hintShortcut,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11,
                    color: lum.g400,
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    _controller.clear();
                    _removeOverlay();
                  },
                  child: Icon(LucideIcons.x, size: 15, color: lum.g400),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty on touch platforms, where a keyboard hint would be meaningless.
  static String _shortcutHint() {
    if (kIsWeb) return '';
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => '⌘K',
      TargetPlatform.windows || TargetPlatform.linux => 'Ctrl K',
      _ => '',
    };
  }
}

class _ResultsPanel extends ConsumerWidget {
  const _ResultsPanel({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<SearchHit> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final state = ref.watch(globalSearchProvider(query));

    return Material(
      color: Colors.transparent,
      child: ClayContainer(
        variant: ClayVariant.raised,
        color: lum.surface,
        borderRadius: AppRadius.lg,
        isDark: lum.isDark,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: switch (state) {
            AsyncValue(hasError: true) =>
              _Message(text: "Couldn't run that search"),
            AsyncValue(:final value?) => value.isEmpty
                ? const _Message(text: 'No matches')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final section in value) ...[
                          _SectionHeading(kind: section.kind),
                          for (final hit in section.hits)
                            _HitRow(hit: hit, onTap: () => onSelect(hit)),
                        ],
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
            _ => const _Message(text: 'Searching…'),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          text,
          style: AppTypography.footnote.copyWith(color: lum.g500),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.kind});

  final SearchKind kind;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final label = switch (kind) {
      SearchKind.product => 'PRODUCTS',
      SearchKind.customer => 'CUSTOMERS',
      SearchKind.invoice => 'INVOICES',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: lum.g500,
        ),
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final icon = switch (hit.kind) {
      SearchKind.product => LucideIcons.package,
      SearchKind.customer => LucideIcons.user,
      SearchKind.invoice => LucideIcons.receipt,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: lum.g500),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: lum.textPrimary,
                    ),
                  ),
                  if (hit.subtitle.isNotEmpty)
                    Text(
                      hit.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.monoValue.copyWith(
                        fontSize: 12,
                        color: lum.g500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: lum.g400),
          ],
        ),
      ),
    );
  }
}
