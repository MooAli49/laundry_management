class CarpetSize {
  final String id;
  final double length;
  final double width;
  final double area;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CarpetSize({
    required this.id,
    required this.length,
    required this.width,
    required this.area,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('CarpetSize id cannot be empty');
    }
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'CarpetSize length must be greater than 0');
    }
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'CarpetSize width must be greater than 0');
    }
    if (area <= 0) {
      throw ArgumentError.value(area, 'area', 'CarpetSize area must be greater than 0');
    }
  }

  CarpetSize copyWith({
    String? id,
    double? length,
    double? width,
    double? area,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarpetSize(
      id: id ?? this.id,
      length: length ?? this.length,
      width: width ?? this.width,
      area: area ?? this.area,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarpetSize &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          length == other.length &&
          width == other.width &&
          area == other.area &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, length, width, area, isActive, createdAt, updatedAt);

  @override
  String toString() => 'CarpetSize(id: $id, ${length}m x ${width}m = ${area}m², active: $isActive)';
}
