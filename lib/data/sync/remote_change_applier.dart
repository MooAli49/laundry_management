import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/daos/sync_state_dao.dart';
import '../local/database/app_database.dart' as app_db;
import '../remote/dto/pull_changes_response_dto.dart';
import '../remote/dto/sync_change_dto.dart';

/// Infrastructure service responsible for applying pulled remote changes directly
/// to local Drift storage and atomically advancing the sync cursor.
///
/// Follows `docs/08-implementation/synchronization-implementation.md` §67 and §68.
///
/// Strict Architectural Invariants:
/// 1. **Atomicity**: Changes and cursor advancement commit within a SINGLE SQLite transaction.
/// 2. **Echo Loop Prevention**: Writes directly to Drift DAOs/tables, NEVER enqueuing `SyncOperation` records.
/// 3. **Strict Sequence Ordering**: Enforces strict ascending sequence ordering.
/// 4. **Storage Invariant**: Enforces `One OrderItem -> Maximum One Active StorageRecord`
///    via explicit synchronization rules, without invoking business repositories or use cases.
/// 5. **Idempotent Replay**: Re-applying identical changes produces identical local state safely.
class RemoteChangeApplier {
  final app_db.AppDatabase _db;
  final SyncStateDao _syncStateDao;

  RemoteChangeApplier({
    required app_db.AppDatabase db,
    required SyncStateDao syncStateDao,
  })  : _db = db,
        _syncStateDao = syncStateDao;

  /// Applies a full page response from the Pull API.
  Future<void> applyPage(PullChangesResponseDto page) async {
    await applyBatch(page.changes);
  }

  /// Applies a batch of remote sync changes in strict ascending sequence order.
  ///
  /// Either all changes in the batch are committed and the sync cursor advances,
  /// or if any change fails, the entire transaction rolls back cleanly.
  Future<void> applyBatch(List<SyncChangeDto> changes) async {
    if (changes.isEmpty) return;

    // Defensively validate strict ascending sequence order.
    // The Pull API contract guarantees ascending sequence order;
    // RemoteChangeApplier must not silently sort to hide contract defects.
    for (var i = 1; i < changes.length; i++) {
      if (changes[i].sequence <= changes[i - 1].sequence) {
        throw StateError(
          'Remote sync changes must be in strict ascending sequence order. '
          'Found sequence ${changes[i].sequence} after ${changes[i - 1].sequence}.',
        );
      }
    }

    await _db.transaction(() async {
      for (final change in changes) {
        await _applySingleChange(change);
      }

      // Cursor advances only after all changes in the batch succeed
      await _syncStateDao.updateLastAppliedSequence(changes.last.sequence);
    });
  }

  /// Dispatches and applies a single remote change by entity type and operation type.
  Future<void> _applySingleChange(SyncChangeDto change) async {
    switch (change.entityType) {
      case 'customer':
        await _applyCustomer(change);
        break;
      case 'order':
        await _applyOrder(change);
        break;
      case 'payment':
        await _applyPayment(change);
        break;
      case 'storage_record':
        await _applyStorageRecord(change);
        break;
      case 'expense':
        await _applyExpense(change);
        break;
      case 'expense_category':
        await _applyExpenseCategory(change);
        break;
      case 'service':
        await _applyService(change);
        break;
      case 'item_type':
        await _applyItemType(change);
        break;
      case 'item_definition':
        await _applyItemDefinition(change);
        break;
      case 'carpet_size':
        await _applyCarpetSize(change);
        break;
      case 'storage_location':
        await _applyStorageLocation(change);
        break;
      case 'business_settings':
        await _applyBusinessSettings(change);
        break;
      default:
        throw UnsupportedError(
          'Unsupported remote entity type: ${change.entityType}',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Customer Ingestion
  // ---------------------------------------------------------------------------
  Future<void> _applyCustomer(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.CustomersCompanion(
      id: Value(id),
      name: Value(payload['name'] as String? ?? ''),
      phone: Value(payload['phone'] as String? ?? ''),
      notes: Value(payload['notes'] as String?),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.customers).insertOnConflictUpdate(companion);
  }

  // ---------------------------------------------------------------------------
  // Order Ingestion (Aggregate Creation vs Subsequent Updates)
  // ---------------------------------------------------------------------------
  Future<void> _applyOrder(SyncChangeDto change) async {
    final payload = change.payload;
    final orderId = payload['id'] as String? ?? change.entityId;

    if (change.operationType == 'create') {
      // Order Creation Aggregate Snapshot:
      // Dependency order: Customer -> Order Header -> Order Items -> Order Item Carpet
      final orderCompanion = app_db.OrdersCompanion(
        id: Value(orderId),
        orderNumber: Value(payload['order_number'] as String? ?? ''),
        customerId: Value(payload['customer_id'] as String? ?? ''),
        customerNameSnapshot: Value(
          payload['customer_name_snapshot'] as String? ?? '',
        ),
        customerPhoneSnapshot: Value(
          payload['customer_phone_snapshot'] as String? ?? '',
        ),
        status: Value(payload['status'] as String? ?? 'processing'),
        expectedPickupDate: Value(
          payload['expected_pickup_date'] != null
              ? DateTime.parse(payload['expected_pickup_date'] as String)
              : DateTime.now(),
        ),
        notes: Value(payload['notes'] as String?),
        customerPickupRequested: Value(
          payload['customer_pickup_requested'] as bool? ?? false,
        ),
        customerPickupFee: Value(
          (payload['customer_pickup_fee'] as num?)?.toInt() ?? 0,
        ),
        customerDeliveryRequested: Value(
          payload['customer_delivery_requested'] as bool? ?? false,
        ),
        customerDeliveryFee: Value(
          (payload['customer_delivery_fee'] as num?)?.toInt() ?? 0,
        ),
        subtotal: Value((payload['subtotal'] as num?)?.toInt() ?? 0),
        discount: Value((payload['discount'] as num?)?.toInt() ?? 0),
        tax: Value((payload['tax'] as num?)?.toInt() ?? 0),
        total: Value((payload['total'] as num?)?.toInt() ?? 0),
        completedAt: Value(
          payload['completed_at'] != null
              ? DateTime.parse(payload['completed_at'] as String)
              : null,
        ),
        cancelledAt: Value(
          payload['cancelled_at'] != null
              ? DateTime.parse(payload['cancelled_at'] as String)
              : null,
        ),
        cancellationReason: Value(payload['cancellation_reason'] as String?),
        createdAt: Value(
          payload['created_at'] != null
              ? DateTime.parse(payload['created_at'] as String)
              : change.createdAt,
        ),
        updatedAt: Value(
          payload['updated_at'] != null
              ? DateTime.parse(payload['updated_at'] as String)
              : change.createdAt,
        ),
      );

      // 1. Upsert Order Header
      await _db.into(_db.orders).insertOnConflictUpdate(orderCompanion);

      // 2. Unpack nested Order Items & Carpets
      final rawItems = payload['items'] as List<dynamic>? ?? [];
      for (final rawItem in rawItems) {
        if (rawItem is! Map<String, dynamic>) continue;
        final itemId = rawItem['id'] as String;

        final itemCompanion = app_db.OrderItemsCompanion(
          id: Value(itemId),
          orderId: Value(orderId),
          itemTypeId: Value(rawItem['item_type_id'] as String? ?? ''),
          itemDefinitionId: Value(rawItem['item_definition_id'] as String?),
          serviceId: Value(rawItem['service_id'] as String? ?? ''),
          itemTypeNameSnapshot: Value(
            rawItem['item_type_name_snapshot'] as String? ?? '',
          ),
          itemDefinitionNameSnapshot: Value(
            rawItem['item_definition_name_snapshot'] as String?,
          ),
          serviceNameSnapshot: Value(
            rawItem['service_name_snapshot'] as String? ?? '',
          ),
          pricingType: Value(rawItem['pricing_type'] as String? ?? 'per_piece'),
          quantity: Value((rawItem['quantity'] as num?)?.toDouble() ?? 1.0),
          unitPrice: Value((rawItem['unit_price'] as num?)?.toInt() ?? 0),
          calculatedTotal: Value(
            (rawItem['calculated_total'] as num?)?.toInt() ?? 0,
          ),
          notes: Value(rawItem['notes'] as String?),
          createdAt: Value(
            rawItem['created_at'] != null
                ? DateTime.parse(rawItem['created_at'] as String)
                : change.createdAt,
          ),
          updatedAt: Value(
            rawItem['updated_at'] != null
                ? DateTime.parse(rawItem['updated_at'] as String)
                : change.createdAt,
          ),
        );

        await _db.into(_db.orderItems).insertOnConflictUpdate(itemCompanion);

        // 3. Optional carpet details
        final rawCarpet =
            rawItem['carpet_data'] ?? rawItem['carpet'];
        if (rawCarpet is Map<String, dynamic>) {
          final carpetId = rawCarpet['id'] as String;
          final carpetCompanion = app_db.OrderItemCarpetsCompanion(
            id: Value(carpetId),
            orderItemId: Value(itemId),
            carpetSizeId: Value(rawCarpet['carpet_size_id'] as String?),
            length: Value((rawCarpet['length'] as num?)?.toDouble() ?? 0.0),
            width: Value((rawCarpet['width'] as num?)?.toDouble() ?? 0.0),
            area: Value((rawCarpet['area'] as num?)?.toDouble() ?? 0.0),
            createdAt: Value(
              rawCarpet['created_at'] != null
                  ? DateTime.parse(rawCarpet['created_at'] as String)
                  : change.createdAt,
            ),
            updatedAt: Value(
              rawCarpet['updated_at'] != null
                  ? DateTime.parse(rawCarpet['updated_at'] as String)
                  : change.createdAt,
            ),
          );

          await _db
              .into(_db.orderItemCarpets)
              .insertOnConflictUpdate(carpetCompanion);
        }
      }
    } else {
      // Subsequent Order updates (e.g. status transition, notes, cancellation)
      // Updates only the Order header row; does not modify items or carpets.
      final updates = app_db.OrdersCompanion(
        id: Value(orderId),
        orderNumber: payload.containsKey('order_number')
            ? Value(payload['order_number'] as String)
            : const Value.absent(),
        customerId: payload.containsKey('customer_id')
            ? Value(payload['customer_id'] as String)
            : const Value.absent(),
        status: payload.containsKey('status')
            ? Value(payload['status'] as String)
            : const Value.absent(),
        expectedPickupDate: payload.containsKey('expected_pickup_date') &&
                payload['expected_pickup_date'] != null
            ? Value(DateTime.parse(payload['expected_pickup_date'] as String))
            : const Value.absent(),
        notes: payload.containsKey('notes')
            ? Value(payload['notes'] as String?)
            : const Value.absent(),
        completedAt: payload.containsKey('completed_at')
            ? Value(
                payload['completed_at'] != null
                    ? DateTime.parse(payload['completed_at'] as String)
                    : null,
              )
            : const Value.absent(),
        cancelledAt: payload.containsKey('cancelled_at')
            ? Value(
                payload['cancelled_at'] != null
                    ? DateTime.parse(payload['cancelled_at'] as String)
                    : null,
              )
            : const Value.absent(),
        cancellationReason: payload.containsKey('cancellation_reason')
            ? Value(payload['cancellation_reason'] as String?)
            : const Value.absent(),
        subtotal: payload.containsKey('subtotal')
            ? Value((payload['subtotal'] as num).toInt())
            : const Value.absent(),
        discount: payload.containsKey('discount')
            ? Value((payload['discount'] as num).toInt())
            : const Value.absent(),
        tax: payload.containsKey('tax')
            ? Value((payload['tax'] as num).toInt())
            : const Value.absent(),
        total: payload.containsKey('total')
            ? Value((payload['total'] as num).toInt())
            : const Value.absent(),
        updatedAt: Value(
          payload['updated_at'] != null
              ? DateTime.parse(payload['updated_at'] as String)
              : change.createdAt,
        ),
      );

      await (_db.update(_db.orders)..where((t) => t.id.equals(orderId)))
          .write(updates);
    }
  }

  // ---------------------------------------------------------------------------
  // Payment Ingestion (Append-only & Idempotent)
  // ---------------------------------------------------------------------------
  Future<void> _applyPayment(SyncChangeDto change) async {
    final payload = change.payload;
    final paymentId = payload['id'] as String? ?? change.entityId;

    final companion = app_db.PaymentsCompanion(
      id: Value(paymentId),
      orderId: Value(payload['order_id'] as String? ?? ''),
      amount: Value((payload['amount'] as num?)?.toInt() ?? 0),
      paymentMethod: Value(payload['payment_method'] as String? ?? 'cash'),
      paidAt: Value(
        payload['paid_at'] != null
            ? DateTime.parse(payload['paid_at'] as String)
            : change.createdAt,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.payments).insertOnConflictUpdate(companion);
  }

  // ---------------------------------------------------------------------------
  // Storage Record Ingestion (Critical Storage Apply Rules)
  // ---------------------------------------------------------------------------
  Future<void> _applyStorageRecord(SyncChangeDto change) async {
    final payload = change.payload;
    final recordId = payload['id'] as String? ?? change.entityId;
    final orderItemId = payload['order_item_id'] as String? ?? '';
    final locationId = payload['storage_location_id'] as String? ?? '';

    // Determine active status: explicit payload is_active takes precedence,
    // or unstore operation type means false.
    final bool isActive;
    if (payload.containsKey('is_active')) {
      isActive = payload['is_active'] as bool;
    } else if (payload.containsKey('isActive')) {
      isActive = payload['isActive'] as bool;
    } else {
      isActive = change.operationType != 'unstore';
    }

    final updatedAt = payload['updated_at'] != null
        ? DateTime.parse(payload['updated_at'] as String)
        : change.createdAt;
    final createdAt = payload['created_at'] != null
        ? DateTime.parse(payload['created_at'] as String)
        : updatedAt;

    // CRITICAL STORAGE APPLY RULE:
    // Local invariant: One OrderItem -> Maximum One Active StorageRecord
    // (idx_storage_records_active_item: UNIQUE(order_item_id) WHERE is_active = 1)
    //
    // If and ONLY if the incoming record is active:
    // Deactivate any existing active storage record for this order_item_id
    // that is NOT this record. This is a pure sync application rule;
    // it does NOT invoke repositories, use cases, or emit domain events.
    if (isActive && orderItemId.isNotEmpty) {
      await (_db.update(_db.storageRecords)
            ..where(
              (t) =>
                  t.orderItemId.equals(orderItemId) &
                  t.isActive.equals(true) &
                  t.id.isNotValue(recordId),
            ))
          .write(
            app_db.StorageRecordsCompanion(
              isActive: const Value(false),
              updatedAt: Value(updatedAt),
            ),
          );
    }

    final companion = app_db.StorageRecordsCompanion(
      id: Value(recordId),
      orderItemId: Value(orderItemId),
      storageLocationId: Value(locationId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );

    await _db.into(_db.storageRecords).insertOnConflictUpdate(companion);
  }

  // ---------------------------------------------------------------------------
  // Expenses & Categories Ingestion
  // ---------------------------------------------------------------------------
  Future<void> _applyExpense(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    String categorySnapshot =
        payload['category_name_snapshot'] as String? ?? '';
    if (categorySnapshot.isEmpty && payload.containsKey('expense_category_id')) {
      final cat = await (_db.select(_db.expenseCategories)
            ..where((t) => t.id.equals(payload['expense_category_id'] as String)))
          .getSingleOrNull();
      if (cat != null) {
        categorySnapshot = cat.name;
      }
    }

    final companion = app_db.ExpensesCompanion(
      id: Value(id),
      expenseCategoryId: Value(
        payload['expense_category_id'] as String? ?? '',
      ),
      categoryNameSnapshot: Value(categorySnapshot),
      amount: Value((payload['amount'] as num?)?.toInt() ?? 0),
      expenseName: Value(payload['expense_name'] as String?),
      expenseDate: Value(
        payload['expense_date'] != null
            ? DateTime.parse(payload['expense_date'] as String)
            : change.createdAt,
      ),
      notes: Value(payload['notes'] as String?),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.expenses).insertOnConflictUpdate(companion);
  }

  Future<void> _applyExpenseCategory(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.ExpenseCategoriesCompanion(
      id: Value(id),
      name: Value(payload['name'] as String? ?? ''),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.expenseCategories).insertOnConflictUpdate(companion);
  }

  // ---------------------------------------------------------------------------
  // Master Data Ingestion
  // ---------------------------------------------------------------------------
  Future<void> _applyService(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.ServicesCompanion(
      id: Value(id),
      name: Value(payload['name'] as String? ?? ''),
      description: Value(payload['description'] as String?),
      pricingType: Value(payload['pricing_type'] as String? ?? 'per_piece'),
      price: Value((payload['price'] as num?)?.toInt() ?? 0),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.services).insertOnConflictUpdate(companion);

    // Optional supported item type IDs
    if (payload.containsKey('item_type_ids')) {
      final rawIds = payload['item_type_ids'] as List<dynamic>?;
      if (rawIds != null) {
        await (_db.delete(_db.serviceItemTypes)
              ..where((t) => t.serviceId.equals(id)))
            .go();
        for (final itemTypeId in rawIds) {
          if (itemTypeId is String) {
            await _db.into(_db.serviceItemTypes).insert(
                  app_db.ServiceItemTypesCompanion(
                    id: Value(const Uuid().v4()),
                    serviceId: Value(id),
                    itemTypeId: Value(itemTypeId),
                    createdAt: Value(DateTime.now()),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }
    }
  }

  Future<void> _applyItemType(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.ItemTypesCompanion(
      id: Value(id),
      name: Value(payload['name'] as String? ?? ''),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.itemTypes).insertOnConflictUpdate(companion);
  }

  Future<void> _applyItemDefinition(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.ItemDefinitionsCompanion(
      id: Value(id),
      itemTypeId: Value(payload['item_type_id'] as String? ?? ''),
      name: Value(payload['name'] as String? ?? ''),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.itemDefinitions).insertOnConflictUpdate(companion);
  }

  Future<void> _applyCarpetSize(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.CarpetSizesCompanion(
      id: Value(id),
      length: Value((payload['length'] as num?)?.toDouble() ?? 0.0),
      width: Value((payload['width'] as num?)?.toDouble() ?? 0.0),
      area: Value((payload['area'] as num?)?.toDouble() ?? 0.0),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.carpetSizes).insertOnConflictUpdate(companion);
  }

  Future<void> _applyStorageLocation(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ?? change.entityId;

    final companion = app_db.StorageLocationsCompanion(
      id: Value(id),
      name: Value(payload['name'] as String? ?? ''),
      isActive: Value(
        (payload['is_active'] ?? payload['isActive']) as bool? ?? true,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.storageLocations).insertOnConflictUpdate(companion);

    // Optional supported item type IDs
    if (payload.containsKey('supported_item_type_ids')) {
      final rawIds = payload['supported_item_type_ids'] as List<dynamic>?;
      if (rawIds != null) {
        await (_db.delete(_db.storageLocationItemTypes)
              ..where((t) => t.storageLocationId.equals(id)))
            .go();
        for (final itemTypeId in rawIds) {
          if (itemTypeId is String) {
            await _db.into(_db.storageLocationItemTypes).insert(
                  app_db.StorageLocationItemTypesCompanion(
                    id: Value(const Uuid().v4()),
                    storageLocationId: Value(id),
                    itemTypeId: Value(itemTypeId),
                    createdAt: Value(DateTime.now()),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Business Settings Ingestion
  // ---------------------------------------------------------------------------
  Future<void> _applyBusinessSettings(SyncChangeDto change) async {
    final payload = change.payload;
    final id = payload['id'] as String? ??
        '00000000-0000-0000-0000-000000000001';

    final companion = app_db.BusinessSettingsCompanion(
      id: Value(id),
      businessName: Value(payload['business_name'] as String? ?? ''),
      address: Value(payload['address'] as String?),
      phone: Value(payload['phone'] as String?),
      logoReference: Value(payload['logo_reference'] as String?),
      invoiceFooterText: Value(payload['invoice_footer_text'] as String?),
      taxEnabled: Value(
        (payload['tax_enabled'] ?? payload['taxEnabled']) as bool? ?? false,
      ),
      taxRate: Value(
        ((payload['tax_rate'] ?? payload['taxRate']) as num?)?.toDouble() ??
            0.0,
      ),
      createdAt: Value(
        payload['created_at'] != null
            ? DateTime.parse(payload['created_at'] as String)
            : change.createdAt,
      ),
      updatedAt: Value(
        payload['updated_at'] != null
            ? DateTime.parse(payload['updated_at'] as String)
            : change.createdAt,
      ),
    );

    await _db.into(_db.businessSettings).insertOnConflictUpdate(companion);
  }
}
