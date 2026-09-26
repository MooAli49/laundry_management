import 'sync_change_dto.dart';

/// Typed response from the remote Pull API `GET /sync/changes`.
///
/// Follows `docs/08-implementation/synchronization-implementation.md` §68.3.
class PullChangesResponseDto {
  final List<SyncChangeDto> changes;
  final bool hasMore;
  final int latestSequence;

  const PullChangesResponseDto({
    required this.changes,
    required this.hasMore,
    required this.latestSequence,
  });

  factory PullChangesResponseDto.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List<dynamic>? ?? [];
    final parsedChanges = rawChanges
        .map((c) => SyncChangeDto.fromJson(c as Map<String, dynamic>))
        .toList();

    return PullChangesResponseDto(
      changes: parsedChanges,
      hasMore: json['has_more'] as bool? ?? false,
      latestSequence: (json['latest_sequence'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'changes': changes.map((c) => c.toJson()).toList(),
    'has_more': hasMore,
    'latest_sequence': latestSequence,
  };

  @override
  String toString() =>
      'PullChangesResponseDto(count: ${changes.length}, hasMore: $hasMore, latest: $latestSequence)';
}
