import 'package:drift/drift.dart';

import 'seed_data.dart';

/// Synthetic test data for development and manual testing.
///
/// MUST be strictly separated from production [SeedData].
/// Production seed remains clean and never creates customers, orders,
/// payments, or storage records.
class DevTestData {
  static const bool isEnabled = bool.fromEnvironment('ENABLE_DEV_TEST_DATA', defaultValue: false);

  // Master Data IDs
  static const String srvWashIronId = '00000000-0000-0000-0002-000000000001';
  static const String srvDryCleanId = '00000000-0000-0000-0002-000000000002';
  static const String srvCarpetWashId = '00000000-0000-0000-0002-000000000003';
  static const String srvBlanketId = '00000000-0000-0000-0002-000000000004';
  static const String srvCoverId = '00000000-0000-0000-0002-000000000005';

  static const String typeClothingId = '00000000-0000-0000-0001-000000000001';
  static const String typeBlanketsId = '00000000-0000-0000-0001-000000000002';
  static const String typeCarpetsId = '00000000-0000-0000-0001-000000000003';
  static const String typeCoversId = '00000000-0000-0000-0001-000000000004';

  static const String idefShirtId = '00000000-0000-0000-0005-000000000001';
  static const String idefPantsId = '00000000-0000-0000-0005-000000000002';
  static const String idefSuitId = '00000000-0000-0000-0005-000000000003';
  static const String idefSingleBlanketId = '00000000-0000-0000-0005-000000000004';
  static const String idefDoubleBlanketId = '00000000-0000-0000-0005-000000000005';
  static const String idefWoolCarpetId = '00000000-0000-0000-0005-000000000006';
  static const String idefRunnerCarpetId = '00000000-0000-0000-0005-000000000007';
  static const String idefDuvetCoverId = '00000000-0000-0000-0005-000000000008';
  static const String idefBedspreadId = '00000000-0000-0000-0005-000000000009';
  static const String idefSilkCarpetId = '00000000-0000-0000-0005-000000000010';

  static const String locRackA1Id = '00000000-0000-0000-0006-000000000001';
  static const String locRackA2Id = '00000000-0000-0000-0006-000000000002';
  static const String locRackB1Id = '00000000-0000-0000-0006-000000000003';
  static const String locCarpetSectionId = '00000000-0000-0000-0006-000000000004';
  static const String locBlanketSectionId = '00000000-0000-0000-0006-000000000005';

  static const String carpetSize2x3Id = '00000000-0000-0000-0007-000000000001';
  static const String carpetSize1_5x2Id = '00000000-0000-0000-0007-000000000002';
  static const String carpetSize1x4Id = '00000000-0000-0000-0007-000000000003';

  /// Seed development test data idempotently.
  static Future<void> seedDevData(GeneratedDatabase db) async {
    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nowDt = DateTime.now();

    // 1. Seed Master Data dependencies for Dev data
    await _seedMasterData(db, nowTimestamp);

    // 2. Seed 12 Customers (idempotent)
    final customerNames = [
      'أحمد محمود',
      'محمد علي',
      'سارة حسن',
      'خالد إبراهيم',
      'فاطمة عمر',
      'عمرو يوسف',
      'ياسمين طارق',
      'هشام فوزي',
      'رانيا مجدي',
      'كريم مصطفى',
      'ندى عبد الرحمن',
      'عمر صلاح',
    ];

    for (var i = 1; i <= 12; i++) {
      final custId = _formatUuid(3, i);
      final phone = '010000000${i.toString().padLeft(2, '0')}';
      await db.customStatement(
        'INSERT OR IGNORE INTO customers (id, name, phone, notes, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?);',
        [custId, customerNames[i - 1], phone, 'عميل تجريبي للتطوير #$i', nowTimestamp, nowTimestamp],
      );
    }

    // 3. Seed 18 Orders and related items/payments/storage
    await _seedOrders(db, nowDt, nowTimestamp);
  }

  static Future<void> _seedMasterData(GeneratedDatabase db, int nowTimestamp) async {
    // Services
    final services = [
      {'id': srvWashIronId, 'name': 'غسيل ومكوى', 'pricing_type': 'perPiece', 'price': 2500},
      {'id': srvDryCleanId, 'name': 'دراي كلين', 'pricing_type': 'perPiece', 'price': 4500},
      {'id': srvCarpetWashId, 'name': 'غسيل سجاد', 'pricing_type': 'perSquareMeter', 'price': 6000},
      {'id': srvBlanketId, 'name': 'تنظيف بطاطين', 'pricing_type': 'fixedPrice', 'price': 8000},
      {'id': srvCoverId, 'name': 'غسيل أغطية', 'pricing_type': 'fixedPrice', 'price': 3500},
    ];

    for (final s in services) {
      await db.customStatement(
        'INSERT OR IGNORE INTO services (id, name, description, pricing_type, price, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, 1, ?, ?);',
        [s['id'], s['name'], 'خدمة تجريبية', s['pricing_type'], s['price'], nowTimestamp, nowTimestamp],
      );
    }

    // Service Item Types links
    final serviceItemTypeLinks = [
      {'service_id': srvWashIronId, 'item_type_id': typeClothingId},
      {'service_id': srvDryCleanId, 'item_type_id': typeClothingId},
      {'service_id': srvCarpetWashId, 'item_type_id': typeCarpetsId},
      {'service_id': srvBlanketId, 'item_type_id': typeBlanketsId},
      {'service_id': srvCoverId, 'item_type_id': typeCoversId},
    ];

    for (var i = 0; i < serviceItemTypeLinks.length; i++) {
      final link = serviceItemTypeLinks[i];
      final linkId = _formatUuid(8, i + 1);
      await db.customStatement(
        'INSERT OR IGNORE INTO service_item_types (id, service_id, item_type_id, created_at) '
        'VALUES (?, ?, ?, ?);',
        [linkId, link['service_id'], link['item_type_id'], nowTimestamp],
      );
    }

    // Item Definitions
    final itemDefs = [
      {'id': idefShirtId, 'item_type_id': typeClothingId, 'name': 'قميص'},
      {'id': idefPantsId, 'item_type_id': typeClothingId, 'name': 'بنطلون'},
      {'id': idefSuitId, 'item_type_id': typeClothingId, 'name': 'بدلة'},
      {'id': idefSingleBlanketId, 'item_type_id': typeBlanketsId, 'name': 'بطانية مفرد'},
      {'id': idefDoubleBlanketId, 'item_type_id': typeBlanketsId, 'name': 'بطانية دبل'},
      {'id': idefWoolCarpetId, 'item_type_id': typeCarpetsId, 'name': 'سجادة صوف'},
      {'id': idefRunnerCarpetId, 'item_type_id': typeCarpetsId, 'name': 'مشاية'},
      {'id': idefDuvetCoverId, 'item_type_id': typeCoversId, 'name': 'غطاء لحاف'},
      {'id': idefBedspreadId, 'item_type_id': typeCoversId, 'name': 'كوفرتة'},
      {'id': idefSilkCarpetId, 'item_type_id': typeCarpetsId, 'name': 'سجادة حرير'},
    ];

    for (final def in itemDefs) {
      await db.customStatement(
        'INSERT OR IGNORE INTO item_definitions (id, item_type_id, name, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, 1, ?, ?);',
        [def['id'], def['item_type_id'], def['name'], nowTimestamp, nowTimestamp],
      );
    }

    // Storage Locations
    final storageLocations = [
      {'id': locRackA1Id, 'name': 'رف أ-1'},
      {'id': locRackA2Id, 'name': 'رف أ-2'},
      {'id': locRackB1Id, 'name': 'رف ب-1'},
      {'id': locCarpetSectionId, 'name': 'قسم السجاد 1'},
      {'id': locBlanketSectionId, 'name': 'قسم البطاطين 1'},
    ];

    for (final loc in storageLocations) {
      await db.customStatement(
        'INSERT OR IGNORE INTO storage_locations (id, name, is_active, created_at, updated_at) '
        'VALUES (?, ?, 1, ?, ?);',
        [loc['id'], loc['name'], nowTimestamp, nowTimestamp],
      );
    }

    // Carpet Sizes
    final carpetSizes = [
      {'id': carpetSize2x3Id, 'length': 2.0, 'width': 3.0, 'area': 6.0},
      {'id': carpetSize1_5x2Id, 'length': 1.5, 'width': 2.0, 'area': 3.0},
      {'id': carpetSize1x4Id, 'length': 1.0, 'width': 4.0, 'area': 4.0},
    ];

    for (final cs in carpetSizes) {
      await db.customStatement(
        'INSERT OR IGNORE INTO carpet_sizes (id, length, width, area, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, 1, ?, ?);',
        [cs['id'], cs['length'], cs['width'], cs['area'], nowTimestamp, nowTimestamp],
      );
    }
  }

  static Future<void> _seedOrders(GeneratedDatabase db, DateTime nowDt, int nowTimestamp) async {
    final expectedPickupDt = nowDt.add(const Duration(days: 3));
    final expectedPickupTimestamp = expectedPickupDt.toUtc().millisecondsSinceEpoch ~/ 1000;

    // Helper for inserting an order
    Future<void> insertOrder({
      required String id,
      required String orderNumber,
      required String customerId,
      required String status,
      required int subtotal,
      int discount = 0,
      int customerPickupFee = 0,
      bool customerPickupRequested = false,
      int customerDeliveryFee = 0,
      bool customerDeliveryRequested = false,
      int? completedAtTimestamp,
      int? cancelledAtTimestamp,
      String? cancellationReason,
    }) async {
      final total = subtotal - discount + customerPickupFee + customerDeliveryFee;
      await db.customStatement(
        'INSERT OR IGNORE INTO orders ('
        'id, order_number, customer_id, status, expected_pickup_date, notes, '
        'customer_pickup_requested, customer_pickup_fee, customer_delivery_requested, customer_delivery_fee, '
        'subtotal, discount, tax, total, completed_at, cancelled_at, cancellation_reason, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?);',
        [
          id,
          orderNumber,
          customerId,
          status,
          expectedPickupTimestamp,
          'طلب تجريبي $orderNumber',
          customerPickupRequested ? 1 : 0,
          customerPickupFee,
          customerDeliveryRequested ? 1 : 0,
          customerDeliveryFee,
          subtotal,
          discount,
          total,
          completedAtTimestamp,
          cancelledAtTimestamp,
          cancellationReason,
          nowTimestamp,
          nowTimestamp,
        ],
      );
    }

    // Helper for inserting an order item
    Future<void> insertItem({
      required String id,
      required String orderId,
      required String itemTypeId,
      String? itemDefinitionId,
      required String serviceId,
      required String itemTypeName,
      String? itemDefinitionName,
      required String serviceName,
      required String pricingType,
      required double quantity,
      required int unitPrice,
      required int calculatedTotal,
      String? notes,
    }) async {
      await db.customStatement(
        'INSERT OR IGNORE INTO order_items ('
        'id, order_id, item_type_id, item_definition_id, service_id, '
        'item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot, '
        'pricing_type, quantity, unit_price, calculated_total, notes, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
        [
          id,
          orderId,
          itemTypeId,
          itemDefinitionId,
          serviceId,
          itemTypeName,
          itemDefinitionName,
          serviceName,
          pricingType,
          quantity,
          unitPrice,
          calculatedTotal,
          notes,
          nowTimestamp,
          nowTimestamp,
        ],
      );
    }

    // Helper for carpet dimension
    Future<void> insertCarpet({
      required String id,
      required String orderItemId,
      required String carpetSizeId,
      required double length,
      required double width,
      required double area,
    }) async {
      await db.customStatement(
        'INSERT OR IGNORE INTO order_item_carpets ('
        'id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?);',
        [id, orderItemId, carpetSizeId, length, width, area, nowTimestamp, nowTimestamp],
      );
    }

    // Helper for payment
    Future<void> insertPayment({
      required String id,
      required String orderId,
      required int amount,
      required String method,
    }) async {
      await db.customStatement(
        'INSERT OR IGNORE INTO payments ('
        'id, order_id, amount, payment_method, paid_at, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?);',
        [id, orderId, amount, method, nowTimestamp, nowTimestamp, nowTimestamp],
      );
    }

    // Helper for storage record
    Future<void> insertStorageRecord({
      required String id,
      required String orderItemId,
      required String storageLocationId,
      required bool isActive,
    }) async {
      await db.customStatement(
        'INSERT OR IGNORE INTO storage_records ('
        'id, order_item_id, storage_location_id, is_active, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?);',
        [id, orderItemId, storageLocationId, isActive ? 1 : 0, nowTimestamp, nowTimestamp],
      );
    }

    // -------------------------------------------------------------
    // Order 1: 26-001 (Processing — no stored items, clothing perPiece)
    // -------------------------------------------------------------
    final ord1 = _formatUuid(4, 1);
    final itm1 = _formatUuid(9, 1);
    await insertOrder(
      id: ord1,
      orderNumber: '26-001',
      customerId: _formatUuid(3, 1),
      status: 'processing',
      subtotal: 2500,
    );
    await insertItem(
      id: itm1,
      orderId: ord1,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );

    // -------------------------------------------------------------
    // Order 2: 26-002 (Processing — partially stored items, 2 physical items)
    // -------------------------------------------------------------
    final ord2 = _formatUuid(4, 2);
    final itm2_1 = _formatUuid(9, 2);
    final itm2_2 = _formatUuid(9, 3);
    await insertOrder(
      id: ord2,
      orderNumber: '26-002',
      customerId: _formatUuid(3, 2),
      status: 'processing',
      subtotal: 6000,
    );
    await insertItem(
      id: itm2_1,
      orderId: ord2,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefPantsId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بنطلون',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 3000,
      calculatedTotal: 3000,
    );
    await insertItem(
      id: itm2_2,
      orderId: ord2,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefPantsId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بنطلون',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 3000,
      calculatedTotal: 3000,
    );
    // Partially stored: item 1 stored, item 2 not stored
    await insertStorageRecord(
      id: _formatUuid(10, 1),
      orderItemId: itm2_1,
      storageLocationId: locRackA1Id,
      isActive: true,
    );

    // -------------------------------------------------------------
    // Order 3: 26-003 (Processing — multiple physical items, clothing)
    // -------------------------------------------------------------
    final ord3 = _formatUuid(4, 3);
    final itm3_1 = _formatUuid(9, 4);
    final itm3_2 = _formatUuid(9, 5);
    final itm3_3 = _formatUuid(9, 6);
    await insertOrder(
      id: ord3,
      orderNumber: '26-003',
      customerId: _formatUuid(3, 3),
      status: 'processing',
      subtotal: 10000,
    );
    await insertItem(
      id: itm3_1,
      orderId: ord3,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertItem(
      id: itm3_2,
      orderId: ord3,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefPantsId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بنطلون',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 3000,
      calculatedTotal: 3000,
    );
    await insertItem(
      id: itm3_3,
      orderId: ord3,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefSuitId,
      serviceId: srvDryCleanId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بدلة',
      serviceName: 'دراي كلين',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 4500,
      calculatedTotal: 4500,
    );

    // -------------------------------------------------------------
    // Order 4: 26-004 (Ready — fully paid, fixed price blanket, stored)
    // -------------------------------------------------------------
    final ord4 = _formatUuid(4, 4);
    final itm4 = _formatUuid(9, 7);
    await insertOrder(
      id: ord4,
      orderNumber: '26-004',
      customerId: _formatUuid(3, 4),
      status: 'ready',
      subtotal: 8000,
    );
    await insertItem(
      id: itm4,
      orderId: ord4,
      itemTypeId: typeBlanketsId,
      itemDefinitionId: idefSingleBlanketId,
      serviceId: srvBlanketId,
      itemTypeName: 'بطاطين',
      itemDefinitionName: 'بطانية مفرد',
      serviceName: 'تنظيف بطاطين',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 8000,
      calculatedTotal: 8000,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 2),
      orderItemId: itm4,
      storageLocationId: locBlanketSectionId,
      isActive: true,
    );
    await insertPayment(
      id: _formatUuid(11, 1),
      orderId: ord4,
      amount: 8000,
      method: 'cash',
    );

    // -------------------------------------------------------------
    // Order 5: 26-005 (Ready — remaining balance, partial payment)
    // -------------------------------------------------------------
    final ord5 = _formatUuid(4, 5);
    final itm5_1 = _formatUuid(9, 8);
    final itm5_2 = _formatUuid(9, 9);
    await insertOrder(
      id: ord5,
      orderNumber: '26-005',
      customerId: _formatUuid(3, 5),
      status: 'ready',
      subtotal: 5000,
    );
    await insertItem(
      id: itm5_1,
      orderId: ord5,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertItem(
      id: itm5_2,
      orderId: ord5,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 3),
      orderItemId: itm5_1,
      storageLocationId: locRackA1Id,
      isActive: true,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 4),
      orderItemId: itm5_2,
      storageLocationId: locRackA2Id,
      isActive: true,
    );
    // Partial payment: 2000 of 5000 via instapay
    await insertPayment(
      id: _formatUuid(11, 2),
      orderId: ord5,
      amount: 2000,
      method: 'instapay',
    );

    // -------------------------------------------------------------
    // Order 6: 26-006 (Completed — fully paid, carpet with dimensions, storage released)
    // -------------------------------------------------------------
    final ord6 = _formatUuid(4, 6);
    final itm6 = _formatUuid(9, 10);
    final crp6 = _formatUuid(12, 1);
    await insertOrder(
      id: ord6,
      orderNumber: '26-006',
      customerId: _formatUuid(3, 6),
      status: 'completed',
      subtotal: 36000,
      completedAtTimestamp: nowTimestamp,
    );
    await insertItem(
      id: itm6,
      orderId: ord6,
      itemTypeId: typeCarpetsId,
      itemDefinitionId: idefWoolCarpetId,
      serviceId: srvCarpetWashId,
      itemTypeName: 'سجاد',
      itemDefinitionName: 'سجادة صوف',
      serviceName: 'غسيل سجاد',
      pricingType: 'perSquareMeter',
      quantity: 1.0,
      unitPrice: 6000,
      calculatedTotal: 36000,
    );
    await insertCarpet(
      id: crp6,
      orderItemId: itm6,
      carpetSizeId: carpetSize2x3Id,
      length: 2.0,
      width: 3.0,
      area: 6.0,
    );
    // Historical inactive storage record
    await insertStorageRecord(
      id: _formatUuid(10, 5),
      orderItemId: itm6,
      storageLocationId: locCarpetSectionId,
      isActive: false,
    );
    await insertPayment(
      id: _formatUuid(11, 3),
      orderId: ord6,
      amount: 36000,
      method: 'cash',
    );

    // -------------------------------------------------------------
    // Order 7: 26-007 (Cancelled — terminal, storage deactivated, cancellation reason)
    // -------------------------------------------------------------
    final ord7 = _formatUuid(4, 7);
    final itm7 = _formatUuid(9, 11);
    await insertOrder(
      id: ord7,
      orderNumber: '26-007',
      customerId: _formatUuid(3, 7),
      status: 'cancelled',
      subtotal: 4500,
      cancelledAtTimestamp: nowTimestamp,
      cancellationReason: 'طلب العميل إلغاء الطلب قبل البدء',
    );
    await insertItem(
      id: itm7,
      orderId: ord7,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefSuitId,
      serviceId: srvDryCleanId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بدلة',
      serviceName: 'دراي كلين',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 4500,
      calculatedTotal: 4500,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 6),
      orderItemId: itm7,
      storageLocationId: locRackB1Id,
      isActive: false,
    );

    // -------------------------------------------------------------
    // Order 8: 26-008 (Discounted order)
    // -------------------------------------------------------------
    final ord8 = _formatUuid(4, 8);
    final itm8_1 = _formatUuid(9, 12);
    final itm8_2 = _formatUuid(9, 13);
    await insertOrder(
      id: ord8,
      orderNumber: '26-008',
      customerId: _formatUuid(3, 8),
      status: 'processing',
      subtotal: 5500,
      discount: 1000,
    );
    await insertItem(
      id: itm8_1,
      orderId: ord8,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertItem(
      id: itm8_2,
      orderId: ord8,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefPantsId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بنطلون',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 3000,
      calculatedTotal: 3000,
    );

    // -------------------------------------------------------------
    // Order 9: 26-009 (Delivery to Laundry only)
    // -------------------------------------------------------------
    final ord9 = _formatUuid(4, 9);
    final itm9 = _formatUuid(9, 14);
    await insertOrder(
      id: ord9,
      orderNumber: '26-009',
      customerId: _formatUuid(3, 9),
      status: 'processing',
      subtotal: 8000,
      customerPickupRequested: true,
      customerPickupFee: 2000,
      customerDeliveryRequested: false,
      customerDeliveryFee: 0,
    );
    await insertItem(
      id: itm9,
      orderId: ord9,
      itemTypeId: typeBlanketsId,
      itemDefinitionId: idefSingleBlanketId,
      serviceId: srvBlanketId,
      itemTypeName: 'بطاطين',
      itemDefinitionName: 'بطانية مفرد',
      serviceName: 'تنظيف بطاطين',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 8000,
      calculatedTotal: 8000,
    );

    // -------------------------------------------------------------
    // Order 10: 26-010 (Delivery to Customer only)
    // -------------------------------------------------------------
    final ord10 = _formatUuid(4, 10);
    final itm10 = _formatUuid(9, 15);
    await insertOrder(
      id: ord10,
      orderNumber: '26-010',
      customerId: _formatUuid(3, 10),
      status: 'processing',
      subtotal: 3500,
      customerPickupRequested: false,
      customerPickupFee: 0,
      customerDeliveryRequested: true,
      customerDeliveryFee: 2500,
    );
    await insertItem(
      id: itm10,
      orderId: ord10,
      itemTypeId: typeCoversId,
      itemDefinitionId: idefDuvetCoverId,
      serviceId: srvCoverId,
      itemTypeName: 'أغطية',
      itemDefinitionName: 'غطاء لحاف',
      serviceName: 'غسيل أغطية',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 3500,
      calculatedTotal: 3500,
    );

    // -------------------------------------------------------------
    // Order 11: 26-011 (Both delivery directions enabled, runner carpet)
    // -------------------------------------------------------------
    final ord11 = _formatUuid(4, 11);
    final itm11 = _formatUuid(9, 16);
    final crp11 = _formatUuid(12, 2);
    await insertOrder(
      id: ord11,
      orderNumber: '26-011',
      customerId: _formatUuid(3, 11),
      status: 'ready',
      subtotal: 24000,
      customerPickupRequested: true,
      customerPickupFee: 3000,
      customerDeliveryRequested: true,
      customerDeliveryFee: 3000,
    );
    await insertItem(
      id: itm11,
      orderId: ord11,
      itemTypeId: typeCarpetsId,
      itemDefinitionId: idefRunnerCarpetId,
      serviceId: srvCarpetWashId,
      itemTypeName: 'سجاد',
      itemDefinitionName: 'مشاية',
      serviceName: 'غسيل سجاد',
      pricingType: 'perSquareMeter',
      quantity: 1.0,
      unitPrice: 6000,
      calculatedTotal: 24000,
    );
    await insertCarpet(
      id: crp11,
      orderItemId: itm11,
      carpetSizeId: carpetSize1x4Id,
      length: 1.0,
      width: 4.0,
      area: 4.0,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 7),
      orderItemId: itm11,
      storageLocationId: locCarpetSectionId,
      isActive: true,
    );
    await insertPayment(
      id: _formatUuid(11, 4),
      orderId: ord11,
      amount: 15000,
      method: 'wallet',
    );

    // -------------------------------------------------------------
    // Order 12: 26-012 (No delivery fees, normal processing)
    // -------------------------------------------------------------
    final ord12 = _formatUuid(4, 12);
    final itm12 = _formatUuid(9, 17);
    await insertOrder(
      id: ord12,
      orderNumber: '26-012',
      customerId: _formatUuid(3, 12),
      status: 'processing',
      subtotal: 2500,
    );
    await insertItem(
      id: itm12,
      orderId: ord12,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );

    // -------------------------------------------------------------
    // Order 13: 26-013 (Price override / historical item pricing)
    // -------------------------------------------------------------
    final ord13 = _formatUuid(4, 13);
    final itm13 = _formatUuid(9, 18);
    await insertOrder(
      id: ord13,
      orderNumber: '26-013',
      customerId: _formatUuid(3, 1),
      status: 'processing',
      subtotal: 3500,
    );
    await insertItem(
      id: itm13,
      orderId: ord13,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefSuitId,
      serviceId: srvDryCleanId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'بدلة',
      serviceName: 'دراي كلين',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 3500, // Overridden from 4500
      calculatedTotal: 3500,
      notes: 'تخفيض خاص لسعر البدلة',
    );

    // -------------------------------------------------------------
    // Order 14: 26-014 (Quantity expansion into 3 physical items + distributed storage across racks)
    // -------------------------------------------------------------
    final ord14 = _formatUuid(4, 14);
    final itm14_1 = _formatUuid(9, 19);
    final itm14_2 = _formatUuid(9, 20);
    final itm14_3 = _formatUuid(9, 21);
    await insertOrder(
      id: ord14,
      orderNumber: '26-014',
      customerId: _formatUuid(3, 2),
      status: 'ready',
      subtotal: 7500,
    );
    await insertItem(
      id: itm14_1,
      orderId: ord14,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertItem(
      id: itm14_2,
      orderId: ord14,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    await insertItem(
      id: itm14_3,
      orderId: ord14,
      itemTypeId: typeClothingId,
      itemDefinitionId: idefShirtId,
      serviceId: srvWashIronId,
      itemTypeName: 'ملابس',
      itemDefinitionName: 'قميص',
      serviceName: 'غسيل ومكوى',
      pricingType: 'perPiece',
      quantity: 1.0,
      unitPrice: 2500,
      calculatedTotal: 2500,
    );
    // Distributed storage across locations
    await insertStorageRecord(
      id: _formatUuid(10, 8),
      orderItemId: itm14_1,
      storageLocationId: locRackA1Id,
      isActive: true,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 9),
      orderItemId: itm14_2,
      storageLocationId: locRackA2Id,
      isActive: true,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 10),
      orderItemId: itm14_3,
      storageLocationId: locRackB1Id,
      isActive: true,
    );
    await insertPayment(
      id: _formatUuid(11, 5),
      orderId: ord14,
      amount: 7500,
      method: 'cash',
    );

    // -------------------------------------------------------------
    // Order 15: 26-015 (Ready — multiple payments: Cash + InstaPay, bedspread cover)
    // -------------------------------------------------------------
    final ord15 = _formatUuid(4, 15);
    final itm15 = _formatUuid(9, 22);
    await insertOrder(
      id: ord15,
      orderNumber: '26-015',
      customerId: _formatUuid(3, 3),
      status: 'ready',
      subtotal: 3500,
    );
    await insertItem(
      id: itm15,
      orderId: ord15,
      itemTypeId: typeCoversId,
      itemDefinitionId: idefBedspreadId,
      serviceId: srvCoverId,
      itemTypeName: 'أغطية',
      itemDefinitionName: 'كوفرتة',
      serviceName: 'غسيل أغطية',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 3500,
      calculatedTotal: 3500,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 11),
      orderItemId: itm15,
      storageLocationId: locBlanketSectionId,
      isActive: true,
    );
    // Payment 1: 1500 Cash
    await insertPayment(
      id: _formatUuid(11, 6),
      orderId: ord15,
      amount: 1500,
      method: 'cash',
    );
    // Payment 2: 2000 InstaPay -> total paid 3500, remaining = 0
    await insertPayment(
      id: _formatUuid(11, 7),
      orderId: ord15,
      amount: 2000,
      method: 'instapay',
    );

    // -------------------------------------------------------------
    // Order 16: 26-016 (Completed — double blanket, fully paid with E-Wallet)
    // -------------------------------------------------------------
    final ord16 = _formatUuid(4, 16);
    final itm16 = _formatUuid(9, 23);
    await insertOrder(
      id: ord16,
      orderNumber: '26-016',
      customerId: _formatUuid(3, 4),
      status: 'completed',
      subtotal: 8000,
      completedAtTimestamp: nowTimestamp,
    );
    await insertItem(
      id: itm16,
      orderId: ord16,
      itemTypeId: typeBlanketsId,
      itemDefinitionId: idefDoubleBlanketId,
      serviceId: srvBlanketId,
      itemTypeName: 'بطاطين',
      itemDefinitionName: 'بطانية دبل',
      serviceName: 'تنظيف بطاطين',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 8000,
      calculatedTotal: 8000,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 12),
      orderItemId: itm16,
      storageLocationId: locBlanketSectionId,
      isActive: false,
    );
    await insertPayment(
      id: _formatUuid(11, 8),
      orderId: ord16,
      amount: 8000,
      method: 'wallet',
    );

    // -------------------------------------------------------------
    // Order 17: 26-017 (Cancelled — blanket, partial payment preserved)
    // -------------------------------------------------------------
    final ord17 = _formatUuid(4, 17);
    final itm17 = _formatUuid(9, 24);
    await insertOrder(
      id: ord17,
      orderNumber: '26-017',
      customerId: _formatUuid(3, 5),
      status: 'cancelled',
      subtotal: 8000,
      cancelledAtTimestamp: nowTimestamp,
      cancellationReason: 'تلف بالقطعة قبل بدء الغسيل',
    );
    await insertItem(
      id: itm17,
      orderId: ord17,
      itemTypeId: typeBlanketsId,
      itemDefinitionId: idefSingleBlanketId,
      serviceId: srvBlanketId,
      itemTypeName: 'بطاطين',
      itemDefinitionName: 'بطانية مفرد',
      serviceName: 'تنظيف بطاطين',
      pricingType: 'fixedPrice',
      quantity: 1.0,
      unitPrice: 8000,
      calculatedTotal: 8000,
    );
    await insertStorageRecord(
      id: _formatUuid(10, 13),
      orderItemId: itm17,
      storageLocationId: locBlanketSectionId,
      isActive: false,
    );
    await insertPayment(
      id: _formatUuid(11, 9),
      orderId: ord17,
      amount: 4000,
      method: 'cash',
    );

    // -------------------------------------------------------------
    // Order 18: 26-018 (Processing — silk carpet with dimensions)
    // -------------------------------------------------------------
    final ord18 = _formatUuid(4, 18);
    final itm18 = _formatUuid(9, 25);
    final crp18 = _formatUuid(12, 3);
    await insertOrder(
      id: ord18,
      orderNumber: '26-018',
      customerId: _formatUuid(3, 6),
      status: 'processing',
      subtotal: 18000,
    );
    await insertItem(
      id: itm18,
      orderId: ord18,
      itemTypeId: typeCarpetsId,
      itemDefinitionId: idefSilkCarpetId,
      serviceId: srvCarpetWashId,
      itemTypeName: 'سجاد',
      itemDefinitionName: 'سجادة حرير',
      serviceName: 'غسيل سجاد',
      pricingType: 'perSquareMeter',
      quantity: 1.0,
      unitPrice: 6000,
      calculatedTotal: 18000,
    );
    await insertCarpet(
      id: crp18,
      orderItemId: itm18,
      carpetSizeId: carpetSize1_5x2Id,
      length: 1.5,
      width: 2.0,
      area: 3.0,
    );
    await insertPayment(
      id: _formatUuid(11, 10),
      orderId: ord18,
      amount: 10000,
      method: 'wallet',
    );
  }

  static String _formatUuid(int group, int index) {
    final groupStr = group.toString().padLeft(4, '0');
    final indexStr = index.toString().padLeft(12, '0');
    return '00000000-0000-0000-$groupStr-$indexStr';
  }
}
