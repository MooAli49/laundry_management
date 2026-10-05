import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/sync/sync_dependency_resolver.dart';

void main() {
  group('SyncDependencyResolver Tests', () {
    final now = DateTime(2026, 10, 1);

    SyncOperation createOp({
      required String id,
      required String entityType,
      required String entityId,
      required String operationType,
      String? payload,
    }) {
      return SyncOperation(
        id: id,
        entityType: entityType,
        entityId: entityId,
        operationType: operationType,
        payload: payload,
        status: 'pending',
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('customer:create has no dependencies', () {
      final op = createOp(
        id: 'op-1',
        entityType: 'customer',
        entityId: 'cust-1',
        operationType: 'create',
        payload: jsonEncode({'id': 'cust-1', 'name': 'Ahmed'}),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, isEmpty);
    });

    test('customer:update depends on customer:cust-1', () {
      final op = createOp(
        id: 'op-2',
        entityType: 'customer',
        entityId: 'cust-1',
        operationType: 'update',
        payload: jsonEncode({'name': 'Ahmed Ali'}),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'customer', entityId: 'cust-1'),
      });
    });

    test('service:create extracts item_type dependencies from service_item_types', () {
      final op = createOp(
        id: 'op-3',
        entityType: 'service',
        entityId: 'srv-1',
        operationType: 'create',
        payload: jsonEncode({
          'id': 'srv-1',
          'name': 'غسيل',
          'service_item_types': [
            {'item_type_id': 'item-type-1', 'price': 5000},
            {'item_type_id': 'item-type-2', 'price': 3000},
          ],
        }),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'item_type', entityId: 'item-type-1'),
        const EntityDependency(entityType: 'item_type', entityId: 'item-type-2'),
      });
    });

    test('order:create extracts customer_id and items references (service_id, item_type_id, etc.)', () {
      final op = createOp(
        id: 'op-4',
        entityType: 'order',
        entityId: 'ord-1',
        operationType: 'create',
        payload: jsonEncode({
          'id': 'ord-1',
          'customer_id': 'cust-1',
          'items': [
            {
              'service_id': 'srv-1',
              'item_type_id': 'item-type-1',
              'item_definition_id': 'def-1',
              'carpet_data': {'carpet_size_id': 'size-1'},
            },
          ],
        }),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'customer', entityId: 'cust-1'),
        const EntityDependency(entityType: 'service', entityId: 'srv-1'),
        const EntityDependency(entityType: 'item_type', entityId: 'item-type-1'),
        const EntityDependency(entityType: 'item_definition', entityId: 'def-1'),
        const EntityDependency(entityType: 'carpet_size', entityId: 'size-1'),
      });
    });

    test('payment:create extracts order_id reference', () {
      final op = createOp(
        id: 'op-5',
        entityType: 'payment',
        entityId: 'pay-1',
        operationType: 'create',
        payload: jsonEncode({'id': 'pay-1', 'order_id': 'ord-1', 'amount': 5000}),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'order', entityId: 'ord-1'),
      });
    });

    test('refund:create extracts order_id reference', () {
      final op = createOp(
        id: 'op-6',
        entityType: 'refund',
        entityId: 'ref-1',
        operationType: 'create',
        payload: jsonEncode({'id': 'ref-1', 'order_id': 'ord-1', 'amount': 2000}),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'order', entityId: 'ord-1'),
      });
    });

    test('expense:create extracts expense_category_id reference', () {
      final op = createOp(
        id: 'op-7',
        entityType: 'expense',
        entityId: 'exp-1',
        operationType: 'create',
        payload: jsonEncode({
          'id': 'exp-1',
          'expense_category_id': 'cat-1',
          'amount': 15000,
        }),
      );

      final deps = SyncDependencyResolver.extractDependencies(op);
      expect(deps, {
        const EntityDependency(entityType: 'expense_category', entityId: 'cat-1'),
      });
    });

    test('storage_record:create extracts storage_location_id and maps order_item_id to order', () {
      final op = createOp(
        id: 'op-8',
        entityType: 'storage_record',
        entityId: 'rec-1',
        operationType: 'create',
        payload: jsonEncode({
          'id': 'rec-1',
          'order_item_id': 'item-1',
          'storage_location_id': 'loc-1',
        }),
      );

      final deps = SyncDependencyResolver.extractDependencies(
        op,
        orderItemToOrderMap: {'item-1': 'ord-1'},
      );
      expect(deps, {
        const EntityDependency(entityType: 'storage_location', entityId: 'loc-1'),
        const EntityDependency(entityType: 'order', entityId: 'ord-1'),
      });
    });
  });
}
