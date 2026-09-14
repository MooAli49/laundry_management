class ItemType {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemType({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ItemType id cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('ItemType name cannot be empty');
    }
  }

  ItemType copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemType(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, name, isActive, createdAt, updatedAt);

  @override
  String toString() => 'ItemType(id: $id, name: $name, active: $isActive)';
}
