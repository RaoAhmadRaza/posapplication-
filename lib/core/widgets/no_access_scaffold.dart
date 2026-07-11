import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

class NoAccessScaffold extends StatelessWidget {
  const NoAccessScaffold({super.key, this.title = 'Access Denied', this.message = 'You do not have permission to access this page.'});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text(title, style: AppTypography.headline),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(message, style: AppTypography.subhead.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
