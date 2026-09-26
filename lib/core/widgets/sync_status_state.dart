import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';

/// Semantic connection and sync status of the application.
enum SyncStatus {
  /// Successful sync completed, backend is healthy, network is connected.
  connected,

  /// Actively synchronizing, or startup initial sync in progress.
  syncing,

  /// Network transport is unavailable or sync failed due to network/transport/timeout.
  offline,

  /// Network is available, but sync failed due to backend/application/server error.
  syncError,
}

/// Immutable UI state for the sync and connection status indicator.
class SyncStatusState {
  final SyncStatus status;
  final String label;
  final Color dotColor;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  const SyncStatusState({
    required this.status,
    required this.label,
    required this.dotColor,
    this.lastSyncTime,
    this.errorMessage,
  });

  /// Factory constructor for the connected state.
  const SyncStatusState.connected({this.lastSyncTime})
      : status = SyncStatus.connected,
        label = AppStrings.syncConnected,
        dotColor = AppColors.success,
        errorMessage = null;

  /// Factory constructor for the active syncing state.
  const SyncStatusState.syncing({this.lastSyncTime})
      : status = SyncStatus.syncing,
        label = AppStrings.syncSyncing,
        dotColor = AppColors.primary,
        errorMessage = null;

  /// Factory constructor for the offline state.
  const SyncStatusState.offline({this.lastSyncTime, this.errorMessage})
      : status = SyncStatus.offline,
        label = AppStrings.syncOffline,
        dotColor = AppColors.warning;

  /// Factory constructor for the sync error state.
  const SyncStatusState.syncError({this.lastSyncTime, this.errorMessage})
      : status = SyncStatus.syncError,
        label = AppStrings.syncError,
        dotColor = AppColors.error;

  bool get isConnected => status == SyncStatus.connected;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isOffline => status == SyncStatus.offline;
  bool get isSyncError => status == SyncStatus.syncError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatusState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          label == other.label &&
          dotColor == other.dotColor &&
          lastSyncTime == other.lastSyncTime &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      label.hashCode ^
      dotColor.hashCode ^
      lastSyncTime.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() =>
      'SyncStatusState(status: $status, label: $label, lastSyncTime: $lastSyncTime, errorMessage: $errorMessage)';
}
