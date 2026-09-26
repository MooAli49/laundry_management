import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../remote/dto/pull_changes_response_dto.dart';
import 'sync_remote_api.dart';

/// High-level remote data source interface for pull synchronization.
abstract class SyncRemoteDataSource {
  /// Fetches a batch of remote changes occurring strictly after [after].
  Future<PullChangesResponseDto> getChanges({
    required int after,
    int? limit,
  });
}

/// Production implementation of [SyncRemoteDataSource] using [SyncRemoteApi].
class SyncRemoteDataSourceImpl implements SyncRemoteDataSource {
  final SyncRemoteApi _api;

  SyncRemoteDataSourceImpl(this._api);

  @override
  Future<PullChangesResponseDto> getChanges({
    required int after,
    int? limit,
  }) async {
    try {
      final response = await _api.getChanges(after: after, limit: limit);
      if (response is Map<String, dynamic>) {
        return PullChangesResponseDto.fromJson(response);
      }
      throw FormatException(
        'Unexpected response format for sync changes: $response',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 410) {
        final data = e.response?.data;
        int? oldestSeq;
        String? message;
        if (data is Map<String, dynamic>) {
          oldestSeq = (data['oldest_available_sequence'] as num?)?.toInt();
          message = data['message'] as String?;
        }
        throw CursorTooOldException(
          message: message ?? 'Client cursor has expired; full resync required.',
          oldestAvailableSequence: oldestSeq,
          cause: e,
        );
      }
      rethrow;
    }
  }
}
