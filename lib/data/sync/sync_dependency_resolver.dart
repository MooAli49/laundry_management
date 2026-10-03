import 'dart:convert';

import '../local/database/app_database.dart' as app_db;

/// Represents an entity identifier dependency (entityType + entityId).
class EntityDependency {
  final String entityType;
  final String entityId;

  const EntityDependency({required this.entityType, required this.entityId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityDependency &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          entityId == other.entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);

  @override
  String toString() => '$entityType:$entityId';
}

/// Helper to deterministically extract parent entity dependencies
/// from sync operations across all application domains.
class SyncDependencyResolver {
  SyncDependencyResolver._();

  static const String malformedPayloadEntityType = '__malformed_payload__';

  static const Map<String, String> _foreignKeyToEntityType = {
    'customer_id': 'customer',
    'order_id': 'order',
    'service_id': 'service',
    'item_type_id': 'item_type',
    'item_definition_id': 'item_definition',
    'carpet_size_id': 'carpet_size',
    'storage_location_id': 'storage_location',
    'previous_storage_location_id': 'storage_location',
    'expense_category_id': 'expense_category',
  };

  /// Extracts parent entity dependencies for a given [operation].
  ///
  /// Dependencies include:
  /// 1. Self-lifecycle: If [operationType] is not 'create' (e.g. 'update', 'status'),
  ///    it depends on the entity itself having been created remotely.
  /// 2. Foreign references: Extracted recursively from the JSON payload
  ///    (e.g., `customer_id`, `service_id`, `order_id`, `item_type_id`, etc.).
  /// 3. If [orderItemToOrderMap] is provided, maps `order_item_id` in storage records
  ///    to its parent `order`.
  static Set<EntityDependency> extractDependencies(
    app_db.SyncOperation operation, {
    Map<String, String>? orderItemToOrderMap,
  }) {
    final deps = <EntityDependency>{};

    // 1. Non-create operations depend on their own entity's creation
    if (operation.operationType != 'create') {
      deps.add(
        EntityDependency(
          entityType: operation.entityType,
          entityId: operation.entityId,
        ),
      );
    }

    // 2. Extract references from payload
    if (operation.payload != null && operation.payload!.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(operation.payload!);
        if (decoded is! Map && decoded is! List) {
          throw const FormatException(
            'Sync payload must be a JSON object or list',
          );
        }
        _extractFromJson(decoded, deps, orderItemToOrderMap);
      } catch (_) {
        deps.add(
          EntityDependency(
            entityType: malformedPayloadEntityType,
            entityId: operation.id,
          ),
        );
      }
    }

    // A create operation never depends on its own entity ID
    if (operation.operationType == 'create') {
      deps.remove(
        EntityDependency(
          entityType: operation.entityType,
          entityId: operation.entityId,
        ),
      );
    }

    return deps;
  }

  static void _extractFromJson(
    dynamic json,
    Set<EntityDependency> deps,
    Map<String, String>? orderItemToOrderMap,
  ) {
    if (json is Map<String, dynamic>) {
      for (final entry in json.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key == 'order_item_id' && value is String && value.isNotEmpty) {
          if (orderItemToOrderMap != null &&
              orderItemToOrderMap.containsKey(value)) {
            deps.add(
              EntityDependency(
                entityType: 'order',
                entityId: orderItemToOrderMap[value]!,
              ),
            );
          }
        } else if (_foreignKeyToEntityType.containsKey(key)) {
          final targetEntityType = _foreignKeyToEntityType[key]!;
          if (value is String && value.isNotEmpty) {
            deps.add(
              EntityDependency(entityType: targetEntityType, entityId: value),
            );
          }
        }

        if (value is Map || value is List) {
          _extractFromJson(value, deps, orderItemToOrderMap);
        }
      }
    } else if (json is List) {
      for (final item in json) {
        _extractFromJson(item, deps, orderItemToOrderMap);
      }
    }
  }
}
