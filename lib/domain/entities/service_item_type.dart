class ServiceItemType {
  final String id;
  final String serviceId;
  final String itemTypeId;
  final DateTime createdAt;

  ServiceItemType({
    required this.id,
    required this.serviceId,
    required this.itemTypeId,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ServiceItemType id cannot be empty');
    }
    if (serviceId.trim().isEmpty) {
      throw ArgumentError('ServiceItemType serviceId cannot be empty');
    }
    if (itemTypeId.trim().isEmpty) {
      throw ArgumentError('ServiceItemType itemTypeId cannot be empty');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceItemType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          serviceId == other.serviceId &&
          itemTypeId == other.itemTypeId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, serviceId, itemTypeId, createdAt);

  @override
  String toString() => 'ServiceItemType(service: $serviceId, itemType: $itemTypeId)';
}
