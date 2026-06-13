import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
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
    if (!_checking && !failed && ok) return Icons.check_circle;
    if (!_checking && failed) return Icons.error;
    return Icons.circle_outlined;
  }

  Color _color(bool ok, bool failed) {
    if (!_checking && !failed && ok) return AppColors.success;
    if (!_checking && failed) return AppColors.destructive;
    return AppColors.textHint;
  }

  String _label(bool ok, bool failed, String pending, String pass, String fail) {
    if (!_checking && !failed && ok) return pass;
    if (!_checking && failed) return fail;
    return pending;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormScaffold(
      title: 'Starting up',
      subtitle: 'Checking your environment...',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _CheckRow(
            icon: _icon(true, _internetFailed),
            color: _color(true, _internetFailed),
            label: _label(true, _internetFailed, 'Checking connection...', 'Connected', 'No internet'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CheckRow(
            icon: _icon(true, _sessionFailed),
            color: _color(true, _sessionFailed),
            label: _label(true, _sessionFailed, 'Restoring session...', 'Session ready', 'Session failed'),
          ),
          if (!_checking && (_internetFailed || _sessionFailed)) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Retry',
              onPressed: _runChecks,
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label, style: AppTypography.subhead),
        ),
      ],
    );
  }
}
