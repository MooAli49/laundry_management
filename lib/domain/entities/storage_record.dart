class StorageRecord {
  final String id;
  final String orderItemId;
  final String storageLocationId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StorageRecord({
    required this.id,
    required this.orderItemId,
    required this.storageLocationId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('StorageRecord id cannot be empty');
    }
    if (orderItemId.trim().isEmpty) {
      throw ArgumentError('StorageRecord orderItemId cannot be empty');
    }
    if (storageLocationId.trim().isEmpty) {
      throw ArgumentError('StorageRecord storageLocationId cannot be empty');
    }
  }

  StorageRecord copyWith({
    String? id,
    String? orderItemId,
    String? storageLocationId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StorageRecord(
      id: id ?? this.id,
      orderItemId: orderItemId ?? this.orderItemId,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderItemId == other.orderItemId &&
          storageLocationId == other.storageLocationId &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, orderItemId, storageLocationId, isActive, createdAt, updatedAt);

  @override
  String toString() =>
      'StorageRecord(id: $id, item: $orderItemId, location: $storageLocationId, active: $isActive)';
}
