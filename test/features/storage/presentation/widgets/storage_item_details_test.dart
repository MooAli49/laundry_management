import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/storage_item.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/entities/storage_record.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/storage/presentation/widgets/move_storage_dialog.dart';
import 'package:laundry_management/features/storage/presentation/widgets/storage_item_card.dart';
import 'package:laundry_management/features/storage/presentation/widgets/store_storage_dialog.dart';

Widget wrapWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  final now = DateTime.now();

  final carpetOrderItem = OrderItem(
    id: 'item-carpet-1',
    orderId: 'order-101',
    itemTypeId: 'type-carpet',
    itemTypeNameSnapshot: 'سجاد',
    itemDefinitionId: 'def-wool',
    itemDefinitionNameSnapshot: 'صوف',
    serviceId: 'srv-wash',
    serviceNameSnapshot: 'غسيل سجاد',
    pricingType: PricingType.perSquareMeter,
    quantity: 1,
    unitPrice: Money.fromEgp(50),
    calculatedTotal: Money.fromEgp(300),
    notes: 'بقعة حبر في الزاوية',
    carpetData: CarpetItemData(
      id: 'carpet-1',
      orderItemId: 'item-carpet-1',
      length: 2.0,
      width: 3.0,
      area: 6.0,
      createdAt: now,
      updatedAt: now,
    ),
    createdAt: now,
    updatedAt: now,
  );

  final nonCarpetOrderItem = OrderItem(
    id: 'item-shirt-1',
    orderId: 'order-102',
    itemTypeId: 'type-clothes',
    itemTypeNameSnapshot: 'ملابس',
    itemDefinitionId: 'def-shirt',
    itemDefinitionNameSnapshot: 'قميص',
    serviceId: 'srv-iron',
    serviceNameSnapshot: 'كي بخار',
    pricingType: PricingType.perPiece,
    quantity: 1,
    unitPrice: Money.fromEgp(15),
    calculatedTotal: Money.fromEgp(15),
    notes: 'مكوي على الوجهين',
    carpetData: null,
    createdAt: now,
    updatedAt: now,
  );

  final loc1 = StorageLocation(
    id: 'loc-rack-1',
    name: 'رف السجاد أ1',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final rec1 = StorageRecord(
    id: 'rec-1',
    orderItemId: 'item-carpet-1',
    storageLocationId: 'loc-rack-1',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final loc2 = StorageLocation(
    id: 'loc-rack-2',
    name: 'قسم الملابس ب2',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final rec2 = StorageRecord(
    id: 'rec-2',
    orderItemId: 'item-shirt-1',
    storageLocationId: 'loc-rack-2',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final storedCarpetStorageItem = StorageItem(
    orderItem: carpetOrderItem,
    orderId: 'order-101',
    orderNumber: '26-101',
    customerName: 'محمد أحمد',
    customerPhone: '0501112233',
    orderStatus: OrderStatus.processing,
    expectedPickupDate: OrderDate.today(),
    orderCreatedAt: now,
    activeRecord: rec1,
    storageLocation: loc1,
  );

  final unstoredCarpetStorageItem = StorageItem(
    orderItem: carpetOrderItem,
    orderId: 'order-101',
    orderNumber: '26-101',
    customerName: 'محمد أحمد',
    customerPhone: '0501112233',
    orderStatus: OrderStatus.processing,
    expectedPickupDate: OrderDate.today(),
    orderCreatedAt: now,
    activeRecord: null,
    storageLocation: null,
  );

  final nonCarpetStorageItem = StorageItem(
    orderItem: nonCarpetOrderItem,
    orderId: 'order-102',
    orderNumber: '26-102',
    customerName: 'علي حسن',
    customerPhone: '0504445566',
    orderStatus: OrderStatus.processing,
    expectedPickupDate: OrderDate.today(),
    orderCreatedAt: now,
    activeRecord: rec2,
    storageLocation: loc2,
  );

  final testDestinationLocation = StorageLocation(
    id: 'loc-dest',
    name: 'رف سجاد بديل',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  group('UAT-A — Storage Item Details in StorageItemCard', () {
    testWidgets('renders carpet dimensions and area when carpetData is present', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          StorageItemCard(
            item: storedCarpetStorageItem,
            onStore: () {},
            onMove: () {},
            onUnstore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Carpet dimensions & area: 2.0 × 3.0 م = 6 م²
      expect(find.text('2.0 × 3.0 م = 6 م²'), findsOneWidget);

      // Existing identification information remains intact
      expect(find.text('سجاد'), findsOneWidget);
      expect(find.text('صوف'), findsOneWidget);
      expect(find.textContaining('غسيل سجاد'), findsOneWidget);
      expect(find.text('#26-101'), findsOneWidget);
      expect(find.textContaining('محمد أحمد'), findsWidgets);
      expect(find.textContaining('بقعة حبر في الزاوية'), findsOneWidget);
      expect(find.text('رف السجاد أ1'), findsOneWidget);
    });

    testWidgets('does NOT render carpet dimensions for non-carpet items', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          StorageItemCard(
            item: nonCarpetStorageItem,
            onStore: () {},
            onMove: () {},
            onUnstore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('م²'), findsNothing);
      expect(find.text('ملابس'), findsOneWidget);
      expect(find.text('قميص'), findsOneWidget);
      expect(find.textContaining('كي بخار'), findsOneWidget);
      expect(find.text('#26-102'), findsOneWidget);
      expect(find.textContaining('علي حسن'), findsWidgets);
      expect(find.textContaining('مكوي على الوجهين'), findsOneWidget);
    });
  });

  group('UAT-A — Storage Item Details in MoveStorageDialog', () {
    testWidgets('displays rich item summary including carpet dimensions and current location', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MoveStorageDialog(
            item: storedCarpetStorageItem,
            destinationLocations: [testDestinationLocation],
            onConfirm: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display type and definition
      expect(find.textContaining('سجاد'), findsWidgets);
      expect(find.textContaining('صوف'), findsWidgets);
      // Dimensions
      expect(find.textContaining('2.0 × 3.0 م = 6 م²'), findsOneWidget);
      // Service
      expect(find.textContaining('غسيل سجاد'), findsWidgets);
      // Order number and customer name
      expect(find.textContaining('#26-101'), findsWidgets);
      expect(find.textContaining('محمد أحمد'), findsWidgets);
      // Current location
      expect(find.textContaining('الموقع الحالي: رف السجاد أ1'), findsOneWidget);
    });
  });

  group('UAT-A — Storage Item Details in StoreStorageDialog', () {
    testWidgets('displays rich item summary including carpet dimensions for single item store', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          StoreStorageDialog(
            itemsToStore: [unstoredCarpetStorageItem],
            availableLocations: [testDestinationLocation],
            onConfirm: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type, definition, dimensions
      expect(find.textContaining('سجاد'), findsWidgets);
      expect(find.textContaining('صوف'), findsWidgets);
      expect(find.textContaining('2.0 × 3.0 م = 6 م²'), findsOneWidget);
      expect(find.textContaining('#26-101'), findsWidgets);
      expect(find.textContaining('محمد أحمد'), findsWidgets);
    });
  });
}
