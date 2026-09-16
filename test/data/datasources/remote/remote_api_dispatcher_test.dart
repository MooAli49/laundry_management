import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

class FakeCustomerApi implements CustomerRemoteApi {
  String? lastOpId;
  String? lastId;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> createCustomer(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastBody = body;
    return {'id': body['id']};
  }

  @override
  Future<dynamic> updateCustomer(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return {'id': id};
  }

  @override
  Future<dynamic> getCustomerById(String id) async => null;

  @override
  Future<dynamic> getCustomers({int? page, int? limit}) async => null;
}

class FakeOrderApi implements OrderRemoteApi {
  String? lastOpId;
  String? lastId;
  Map<String, dynamic>? lastBody;
  bool shouldThrow = false;

  @override
  Future<dynamic> createOrder(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    if (shouldThrow) throw Exception('Order creation remote error');
    lastOpId = operationId;
    lastBody = body;
    return {'id': body['id']};
  }

  @override
  Future<dynamic> updateOrder(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    if (shouldThrow) throw Exception('Order update remote error');
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return {'id': id};
  }

  @override
  Future<dynamic> getOrderById(String id) async => null;

  @override
  Future<dynamic> getOrders({int? page, int? limit}) async => null;
}

class FakePaymentApi implements PaymentRemoteApi {
  String? lastOpId;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> createPayment(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastBody = body;
    return {'id': body['id']};
  }

  @override
  Future<dynamic> getPaymentById(String id) async => null;

  @override
  Future<dynamic> getPayments({String? orderId}) async => null;
}

class FakeStorageApi implements StorageRemoteApi {
  String? lastOpId;
  String? lastId;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> createStorageRecord(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastBody = body;
    return {'id': body['id']};
  }

  @override
  Future<dynamic> updateStorageRecord(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return {'id': id};
  }

  @override
  Future<dynamic> getStorageRecordByOrderItemId(String orderItemId) async =>
      null;

  @override
  Future<dynamic> getStorageRecords({int? page, int? limit}) async => null;
}

class FakeExpenseApi implements ExpenseRemoteApi {
  String? lastOpId;
  String? lastId;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> createExpense(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastBody = body;
    return {'id': body['id']};
  }

  @override
  Future<dynamic> updateExpense(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return {'id': id};
  }

  @override
  Future<dynamic> getExpenseById(String id) async => null;

  @override
  Future<dynamic> getExpenses({
    int? page,
    int? limit,
    String? categoryId,
    String? startDate,
    String? endDate,
  }) async => null;
}

class FakeMasterDataApi implements MasterDataRemoteApi {
  String? lastOpId;
  String? lastId;
  Map<String, dynamic>? lastBody;
  String? lastCalledResource;

  @override
  Future<dynamic> updateBusinessSettings(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'business_settings';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createExpenseCategory(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'expense_category:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateExpenseCategory(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'expense_category:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createService(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'service:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateService(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'service:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createServiceItemType(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'service_item_type:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateServiceItemType(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'service_item_type:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createItemType(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'item_type:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateItemType(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'item_type:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createItemDefinition(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'item_definition:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateItemDefinition(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'item_definition:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createCarpetSize(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'carpet_size:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateCarpetSize(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'carpet_size:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> createStorageLocation(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'storage_location:create';
    lastOpId = operationId;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> updateStorageLocation(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastCalledResource = 'storage_location:update';
    lastOpId = operationId;
    lastId = id;
    lastBody = body;
    return body;
  }

  @override
  Future<dynamic> getBusinessSettings() async => null;
  @override
  Future<dynamic> getCarpetSizeById(String id) async => null;
  @override
  Future<dynamic> getCarpetSizes() async => null;
  @override
  Future<dynamic> getExpenseCategories() async => null;
  @override
  Future<dynamic> getExpenseCategoryById(String id) async => null;
  @override
  Future<dynamic> getItemDefinitionById(String id) async => null;
  @override
  Future<dynamic> getItemDefinitions() async => null;
  @override
  Future<dynamic> getItemTypeById(String id) async => null;
  @override
  Future<dynamic> getItemTypes() async => null;
  @override
  Future<dynamic> getServiceById(String id) async => null;
  @override
  Future<dynamic> getServiceItemTypes() async => null;
  @override
  Future<dynamic> getServices() async => null;
  @override
  Future<dynamic> getStorageLocationById(String id) async => null;
  @override
  Future<dynamic> getStorageLocations() async => null;
}

void main() {
  group('RemoteApiDispatcher Tests', () {
    late FakeCustomerApi customerApi;
    late FakeOrderApi orderApi;
    late FakePaymentApi paymentApi;
    late FakeStorageApi storageApi;
    late FakeExpenseApi expenseApi;
    late FakeMasterDataApi masterDataApi;
    late RemoteApiDispatcher dispatcher;

    final now = DateTime.now();

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

    setUp(() {
      customerApi = FakeCustomerApi();
      orderApi = FakeOrderApi();
      paymentApi = FakePaymentApi();
      storageApi = FakeStorageApi();
      expenseApi = FakeExpenseApi();
      masterDataApi = FakeMasterDataApi();

      dispatcher = RemoteApiDispatcher(
        customerApi: customerApi,
        orderApi: orderApi,
        paymentApi: paymentApi,
        storageApi: storageApi,
        expenseApi: expenseApi,
        masterDataApi: masterDataApi,
      );
    });

    test(
      'dispatches customer create preserving operation ID and payload',
      () async {
        final op = createOp(
          id: 'op-c1',
          entityType: 'customer',
          entityId: 'cust-1',
          operationType: 'create',
          payload: jsonEncode({'name': 'Ali', 'phone': '01000000000'}),
        );

        await dispatcher.dispatch(op);

        expect(customerApi.lastOpId, equals('op-c1'));
        expect(customerApi.lastBody?['name'], equals('Ali'));
        expect(customerApi.lastBody?['id'], equals('cust-1'));
      },
    );

    test(
      'dispatches customer update preserving operation ID and entity ID',
      () async {
        final op = createOp(
          id: 'op-c2',
          entityType: 'customer',
          entityId: 'cust-1',
          operationType: 'update',
          payload: jsonEncode({'name': 'Ali Updated'}),
        );

        await dispatcher.dispatch(op);

        expect(customerApi.lastOpId, equals('op-c2'));
        expect(customerApi.lastId, equals('cust-1'));
        expect(customerApi.lastBody?['name'], equals('Ali Updated'));
      },
    );

    test(
      'dispatches order lifecycle operations (create, update, mark_ready, complete, cancel, status_correction)',
      () async {
        // 1. Create
        await dispatcher.dispatch(
          createOp(
            id: 'op-o-create',
            entityType: 'order',
            entityId: 'ord-1',
            operationType: 'create',
            payload: jsonEncode({'total': 1000}),
          ),
        );
        expect(orderApi.lastOpId, equals('op-o-create'));
        expect(orderApi.lastBody?['total'], equals(1000));

        // 2. Mark Ready
        await dispatcher.dispatch(
          createOp(
            id: 'op-o-ready',
            entityType: 'order',
            entityId: 'ord-1',
            operationType: 'mark_ready',
          ),
        );
        expect(orderApi.lastOpId, equals('op-o-ready'));
        expect(orderApi.lastId, equals('ord-1'));
        expect(orderApi.lastBody?['status'], equals('ready'));

        // 3. Complete
        await dispatcher.dispatch(
          createOp(
            id: 'op-o-complete',
            entityType: 'order',
            entityId: 'ord-1',
            operationType: 'complete',
          ),
        );
        expect(orderApi.lastOpId, equals('op-o-complete'));
        expect(orderApi.lastId, equals('ord-1'));
        expect(orderApi.lastBody?['status'], equals('completed'));

        // 4. Cancel
        await dispatcher.dispatch(
          createOp(
            id: 'op-o-cancel',
            entityType: 'order',
            entityId: 'ord-1',
            operationType: 'cancel',
            payload: 'Customer cancelled',
          ),
        );
        expect(orderApi.lastOpId, equals('op-o-cancel'));
        expect(orderApi.lastId, equals('ord-1'));
        expect(orderApi.lastBody?['status'], equals('cancelled'));

        // 5. Status Correction
        await dispatcher.dispatch(
          createOp(
            id: 'op-o-correct',
            entityType: 'order',
            entityId: 'ord-1',
            operationType: 'status_correction',
            payload: 'Operational correction',
          ),
        );
        expect(orderApi.lastOpId, equals('op-o-correct'));
        expect(orderApi.lastId, equals('ord-1'));
      },
    );

    test('dispatches payment create', () async {
      final op = createOp(
        id: 'op-p-1',
        entityType: 'payment',
        entityId: 'pay-1',
        operationType: 'create',
        payload: jsonEncode({'amount': 5000, 'orderId': 'ord-1'}),
      );

      await dispatcher.dispatch(op);

      expect(paymentApi.lastOpId, equals('op-p-1'));
      expect(paymentApi.lastBody?['amount'], equals(5000));
    });

    test('dispatches storage operations (create, move, unstore)', () async {
      // Create
      await dispatcher.dispatch(
        createOp(
          id: 'op-s-1',
          entityType: 'storage_record',
          entityId: 'sr-1',
          operationType: 'create',
          payload: jsonEncode({
            'orderItemId': 'oi-1',
            'storageLocationId': 'sl-1',
          }),
        ),
      );
      expect(storageApi.lastOpId, equals('op-s-1'));

      // Move
      await dispatcher.dispatch(
        createOp(
          id: 'op-s-2',
          entityType: 'storage_record',
          entityId: 'sr-1',
          operationType: 'move',
          payload: jsonEncode({'storageLocationId': 'sl-2'}),
        ),
      );
      expect(storageApi.lastOpId, equals('op-s-2'));
      expect(storageApi.lastId, equals('sr-1'));

      // Unstore
      await dispatcher.dispatch(
        createOp(
          id: 'op-s-3',
          entityType: 'storage_record',
          entityId: 'sr-1',
          operationType: 'unstore',
        ),
      );
      expect(storageApi.lastOpId, equals('op-s-3'));
      expect(storageApi.lastId, equals('sr-1'));
      expect(storageApi.lastBody?['isActive'], equals(false));
    });

    test('dispatches expense operations (create, update)', () async {
      await dispatcher.dispatch(
        createOp(
          id: 'op-e-1',
          entityType: 'expense',
          entityId: 'exp-1',
          operationType: 'create',
          payload: jsonEncode({'amount': 1500}),
        ),
      );
      expect(expenseApi.lastOpId, equals('op-e-1'));

      await dispatcher.dispatch(
        createOp(
          id: 'op-e-2',
          entityType: 'expense',
          entityId: 'exp-1',
          operationType: 'update',
          payload: jsonEncode({'amount': 2000}),
        ),
      );
      expect(expenseApi.lastOpId, equals('op-e-2'));
      expect(expenseApi.lastId, equals('exp-1'));
    });

    test(
      'dispatches master data operations across categories, services, item types, etc.',
      () async {
        // Expense Category activate
        await dispatcher.dispatch(
          createOp(
            id: 'op-ec-1',
            entityType: 'expense_category',
            entityId: 'cat-1',
            operationType: 'activate',
          ),
        );
        expect(
          masterDataApi.lastCalledResource,
          equals('expense_category:update'),
        );
        expect(masterDataApi.lastBody?['isActive'], isTrue);

        // Service deactivate
        await dispatcher.dispatch(
          createOp(
            id: 'op-srv-1',
            entityType: 'service',
            entityId: 'srv-1',
            operationType: 'deactivate',
          ),
        );
        expect(masterDataApi.lastCalledResource, equals('service:update'));
        expect(masterDataApi.lastBody?['isActive'], isFalse);

        // Item Type create
        await dispatcher.dispatch(
          createOp(
            id: 'op-it-1',
            entityType: 'item_type',
            entityId: 'it-1',
            operationType: 'create',
            payload: jsonEncode({'name': 'قميص'}),
          ),
        );
        expect(masterDataApi.lastCalledResource, equals('item_type:create'));

        // Business Settings update
        await dispatcher.dispatch(
          createOp(
            id: 'op-bs-1',
            entityType: 'business_settings',
            entityId: 'bs-1',
            operationType: 'update',
            payload: jsonEncode({'businessName': 'Clean Laundry'}),
          ),
        );
        expect(masterDataApi.lastCalledResource, equals('business_settings'));
      },
    );

    test('throws UnsupportedError on unknown entity type', () async {
      final op = createOp(
        id: 'op-unknown-ent',
        entityType: 'drone_delivery',
        entityId: 'dd-1',
        operationType: 'create',
      );

      expect(
        () => dispatcher.dispatch(op),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Unsupported sync entity type: drone_delivery'),
          ),
        ),
      );
    });

    test('throws UnsupportedError on unsupported operation type', () async {
      final op = createOp(
        id: 'op-unknown-op',
        entityType: 'customer',
        entityId: 'cust-1',
        operationType: 'nuke_all_data',
      );

      expect(
        () => dispatcher.dispatch(op),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains(
              'Unsupported operation "nuke_all_data" for entity "customer"',
            ),
          ),
        ),
      );
    });

    test(
      'propagates remote exceptions without catching or swallowing them',
      () async {
        orderApi.shouldThrow = true;
        final op = createOp(
          id: 'op-err-1',
          entityType: 'order',
          entityId: 'ord-1',
          operationType: 'create',
        );

        expect(
          () => dispatcher.dispatch(op),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'toString()',
              contains('Order creation remote error'),
            ),
          ),
        );
      },
    );
  });
}
