import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';

class EnvironmentCheckScreen extends StatefulWidget {
  const EnvironmentCheckScreen({super.key});

  @override
  State<EnvironmentCheckScreen> createState() => _EnvironmentCheckScreenState();
}

class _EnvironmentCheckScreenState extends State<EnvironmentCheckScreen> {
  bool _internetFailed = false;
  bool _sessionFailed = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _checking = true;
      _internetFailed = false;
      _sessionFailed = false;
    });

    try {
      await supabase.from('tenants').select('id').limit(1);
      _internetFailed = false;
    } catch (_) {
      _internetFailed = true;
    }

    try {
      supabase.auth.currentSession;
      _sessionFailed = false;
    } catch (_) {
      _sessionFailed = true;
    }

    setState(() => _checking = false);

    if (!_internetFailed && !_sessionFailed) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        EnvCheckState.instance.passed = true;
      }
    }
  }

  IconData _icon(bool ok, bool failed) {
    if (!_checking && !failed && ok) return Icons.check_circle_rounded;
    if (!_checking && failed) return Icons.error_rounded;
    return Icons.circle_outlined;
  }

  Color _color(LumColors lum, bool ok, bool failed) {
    if (!_checking && !failed && ok) return lum.success;
    if (!_checking && failed) return lum.danger;
    return lum.textTertiary;
  }

  Color _textColor(LumColors lum, bool ok, bool failed) {
    if (!_checking && !failed && ok) return lum.successText;
    if (!_checking && failed) return lum.dangerText;
    return lum.textTertiary;
  }

  String _status(bool ok, bool failed, String pending, String pass, String fail) {
    if (!_checking && !failed && ok) return pass;
    if (!_checking && failed) return fail;
    return pending;
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hasFailure = !_checking && (_internetFailed || _sessionFailed);
    final allPassed = !_checking && !_internetFailed && !_sessionFailed;

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Starting up',
        subtitle: 'Checking your environment…',
        children: [
          _CheckRow(
            icon: _icon(true, _internetFailed),
            iconColor: _color(lum, true, _internetFailed),
            label: 'Connection',
            status: _status(
                true, _internetFailed, 'checking…', 'Connected', 'No internet'),
            statusColor: _textColor(lum, true, _internetFailed),
            inProgress: _checking,
          ),
          Divider(color: lum.hairline, height: 1),
          _CheckRow(
            icon: _icon(true, _sessionFailed),
            iconColor: _color(lum, true, _sessionFailed),
            label: 'Session',
            status: _status(
                true, _sessionFailed, 'checking…', 'Ready', 'Failed'),
            statusColor: _textColor(lum, true, _sessionFailed),
            inProgress: _checking,
          ),
          if (allPassed) ...[
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 16, color: lum.successText),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'All checks passed',
                  style: AppTypography.footnote.copyWith(color: lum.successText),
                ),
              ],
            ),
          ],
          if (hasFailure) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _runChecks,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.status,
    required this.statusColor,
    required this.inProgress,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String status;
  final Color statusColor;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: inProgress
                ? Center(
                    child: SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(lum.accent),
                      ),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.subhead.copyWith(color: lum.textPrimary),
            ),
          ),
          Text(
            status,
            style: AppTypography.label.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }
}
