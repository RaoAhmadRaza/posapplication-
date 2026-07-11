import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
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
    // TEMP debug
    debugPrint('[WORKSPACE-INIT] _triggerLoads called, session uid=${supabase.auth.currentUser?.id}, completed=${WorkspaceInitState.instance.completed}');
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

    if (_error) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        size: 32,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Something went wrong',
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppInlineBanner(
                    message: _errorMessage ?? 'Failed to set up your workspace.',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(label: 'Retry', onPressed: _retry),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.dashboard_outlined,
                      size: 32,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Setting up your workspace',
                  style: AppTypography.headline,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Loading your profile and permissions...',
                  style: AppTypography.subhead.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
