class CarpetItemData {
  final String id;
  final String orderItemId;
  final String? carpetSizeId;
  final double length;
  final double width;
  final double area;
  final DateTime createdAt;
  final DateTime updatedAt;

  CarpetItemData({
    required this.id,
    required this.orderItemId,
    this.carpetSizeId,
    required this.length,
    required this.width,
    required this.area,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('CarpetItemData id cannot be empty');
    }
    if (orderItemId.trim().isEmpty) {
      throw ArgumentError('CarpetItemData orderItemId cannot be empty');
    }
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Carpet length must be greater than 0');
    }
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'Carpet width must be greater than 0');
    }
    if (area <= 0) {
      throw ArgumentError.value(area, 'area', 'Carpet area must be greater than 0');
    }
    final expectedArea = length * width;
    if ((area - expectedArea).abs() > 0.001) {
      throw ArgumentError(
        'Carpet area ($area) does not match length ($length) * width ($width) = $expectedArea',
      );
    }
  }

  CarpetItemData copyWith({
    String? id,
    String? orderItemId,
    String? carpetSizeId,
    double? length,
    double? width,
    double? area,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarpetItemData(
      id: id ?? this.id,
      orderItemId: orderItemId ?? this.orderItemId,
      carpetSizeId: carpetSizeId ?? this.carpetSizeId,
      length: length ?? this.length,
      width: width ?? this.width,
      area: area ?? this.area,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarpetItemData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderItemId == other.orderItemId &&
          carpetSizeId == other.carpetSizeId &&
          length == other.length &&
          width == other.width &&
          area == other.area &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        orderItemId,
        carpetSizeId,
        length,
        width,
        area,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'CarpetItemData(id: $id, orderItemId: $orderItemId, ${length}m x ${width}m = ${area}m²)';
}
