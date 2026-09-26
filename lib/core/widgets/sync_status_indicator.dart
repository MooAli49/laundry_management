import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sync_status_cubit.dart';
import 'sync_status_state.dart';

/// Isolated, dynamic indicator widget displaying connection and sync health.
///
/// Renders at the bottom of the sidebar with exact 8x8 dot / spinner visual footprint,
/// RTL layout alignment, and semantic color coding according to the design system.
class SyncStatusIndicator extends StatelessWidget {
  final SyncStatusCubit? cubit;

  const SyncStatusIndicator({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _SyncStatusView(),
      );
    }
    return BlocProvider(
      create: (_) => getIt<SyncStatusCubit>(),
      child: const _SyncStatusView(),
    );
  }
}

class _SyncStatusView extends StatelessWidget {
  const _SyncStatusView();

  Widget _buildIndicator(SyncStatus status, Color dotColor) {
    if (status == SyncStatus.syncing) {
      return const SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIndicator(state.status, state.dotColor),
              AppSpacing.gapHorizontalSm,
              Flexible(
                child: Text(
                  state.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
