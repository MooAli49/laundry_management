class SyncConflictException implements Exception {
  final String conflictType;
  final String entityId;
  final String message;

  const SyncConflictException({
    required this.conflictType,
    required this.entityId,
    required this.message,
  });

  @override
  String toString() =>
      'SyncConflictException($conflictType, $entityId): $message';
}
