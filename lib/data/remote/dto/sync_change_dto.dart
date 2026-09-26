/// Typed Data Transfer Object for a single remote change entry from `sync_changes`.
///
/// Follows `docs/08-implementation/synchronization-implementation.md` §68.1.
class SyncChangeDto {
  final int sequence;
  final String operationId;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final int? serverVersion;
  final DateTime createdAt;

  const SyncChangeDto({
    required this.sequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    this.serverVersion,
    required this.createdAt,
  });

  factory SyncChangeDto.fromJson(Map<String, dynamic> json) {
    return SyncChangeDto(
      sequence: (json['sequence'] as num).toInt(),
      operationId: json['operation_id'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      operationType: json['operation_type'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      serverVersion: (json['server_version'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'sequence': sequence,
    'operation_id': operationId,
    'entity_type': entityType,
    'entity_id': entityId,
    'operation_type': operationType,
    'payload': payload,
    if (serverVersion != null) 'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'SyncChangeDto(seq: $sequence, opId: $operationId, entity: $entityType:$entityId, op: $operationType)';
}
