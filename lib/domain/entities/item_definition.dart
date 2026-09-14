class ItemDefinition {
  final String id;
  final String itemTypeId;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemDefinition({
    required this.id,
    required this.itemTypeId,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ItemDefinition id cannot be empty');
    }
    if (itemTypeId.trim().isEmpty) {
      throw ArgumentError('ItemDefinition itemTypeId cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('ItemDefinition name cannot be empty');
    }
  }

  ItemDefinition copyWith({
    String? id,
    String? itemTypeId,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemDefinition(
      id: id ?? this.id,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemTypeId == other.itemTypeId &&
          name == other.name &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, itemTypeId, name, isActive, createdAt, updatedAt);

  @override
  String toString() =>
      'ItemDefinition(id: $id, itemType: $itemTypeId, name: $name, active: $isActive)';
}
