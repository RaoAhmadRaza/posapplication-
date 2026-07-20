import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/pin_service.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';
import '../controllers/branch_controller.dart';
import '../controllers/permission_controller.dart';
import '../controllers/profile_controller.dart';
import '../../domain/usecases/needs_aal2.dart';

class WorkspaceInitScreen extends ConsumerStatefulWidget {
  const WorkspaceInitScreen({super.key});

  @override
  ConsumerState<WorkspaceInitScreen> createState() => _WorkspaceInitScreenState();
}

class _WorkspaceInitScreenState extends ConsumerState<WorkspaceInitScreen> {
  bool _error = false;
  String? _errorMessage;
  Timer? _timer;
  bool _mfaChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerLoads());
    _startTimeout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        if (!WorkspaceInitState.instance.completed && !MfaState.instance.needsMfa) {
          _error = true;
          _errorMessage = 'Setup is taking longer than expected. Check your connection and retry.';
        }
      });
    });
  }

  void _triggerLoads() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    ref.read(profileControllerProvider.notifier).load(userId);
  }

  Future<void> _complete() async {
    if (_mfaChecked) return;
    _mfaChecked = true;

    final needsAal2 = ref.read(needsAal2UseCaseProvider).call();
    if (needsAal2) {
      MfaState.instance.require();
    } else {
      WorkspaceInitState.instance.completed = true;
    }
  }

  void _retry() {
    _mfaChecked = false;
    setState(() {
      _error = false;
      _errorMessage = null;
    });
    _startTimeout();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerLoads());
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> _reconcilePin() async {
    final serverHash = await PinService.instance.getServerPinHash();
    if (serverHash != null) {
      await PinService.instance.reconcilePinFromServer(serverHash);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileControllerProvider, (prev, next) {
      if (next is AsyncData && next.value != null) {
        final profile = next.value!;
        final prevProfile = prev?.value;
        final userId = supabase.auth.currentUser?.id;

        if (profile.roleId != null && prevProfile?.roleId != profile.roleId) {
          ref.read(permissionMatrixProvider.notifier).load(profile.roleId!);
        }
        if (userId != null && prevProfile == null) {
          ref.read(userBranchesProvider.notifier).load(userId);
        }
        if (profile.tenantId != null &&
            userId != null &&
            prevProfile?.tenantId != profile.tenantId) {
          DeviceService.instance.registerDevice(
            userId: userId,
            tenantId: profile.tenantId!,
          );
        }
        if (prevProfile == null) {
          _reconcilePin();
        }
      }

      if (next.hasError) {
        setState(() {
          _error = true;
          _errorMessage = 'Failed to load profile. Check your connection and retry.';
        });
      }
    });

    final permsReady = ref.watch(permissionsReadyProvider);
    final branchesReady = ref.watch(branchesReadyProvider);

    if (permsReady &&
        branchesReady &&
        !MfaState.instance.needsMfa &&
        !WorkspaceInitState.instance.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
    }

    final lum = context.lum;

    final signOutButton = AppButton(
      label: 'Not you? Sign out',
      variant: AppButtonVariant.plain,
      onPressed: _signOut,
      fullWidth: true,
    );

    if (_error) {
      return AuthHeroScaffold(
        child: AuthFormCard(
          title: 'Starting up',
          subtitle: 'Setting up your workspace…',
          children: [
            AppInlineBanner(
              message: _errorMessage ?? 'Failed to set up your workspace.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _retry,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            signOutButton,
          ],
        ),
      );
    }

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Starting up',
        subtitle: 'Setting up your workspace…',
        children: [
          _StepRow(
            label: 'Profile & permissions',
            done: permsReady,
            lum: lum,
          ),
          const SizedBox(height: AppSpacing.lg),
          _StepRow(
            label: 'Branches & assignments',
            done: branchesReady,
            lum: lum,
          ),
          const SizedBox(height: AppSpacing.lg),
          _StepRow(
            label: 'Device & PIN sync',
            done: permsReady && branchesReady,
            lum: lum,
          ),
          const SizedBox(height: AppSpacing.xl),
          signOutButton,
        ],
      ),
    );
  }
}

/// One line in the workspace-init progress list: a Lumen spinner while pending,
/// a success check once the underlying provider reports ready.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.lum,
  });

  final String label;
  final bool done;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: done
              ? Icon(Icons.check_circle_rounded, size: 22, color: lum.success)
              : CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(lum.accent),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTypography.subhead.copyWith(
              color: done ? lum.textPrimary : lum.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
