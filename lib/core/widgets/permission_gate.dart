import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/controllers/permission_controller.dart';

/// PermissionGate(module: 'sales', action: 'create', child: NewSaleButton());
/// PermissionGate(module: 'reports', action: 'view', child: ReportsTab(), fallback: Text('No access'));
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.module,
    required this.action,
    required this.child,
    this.fallback,
  });

  final String module;
  final String action;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionMatrixProvider);
    final fallback = this.fallback ?? const SizedBox.shrink();

    if (state.isLoading || state.hasError) return fallback;

    final matrix = state.value!;
    final key = '$module:$action';
    return matrix.contains(key) ? child : fallback;
  }
}
