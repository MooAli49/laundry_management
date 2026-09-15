import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';

void main() {
  group('Retrofit APIs HTTP Contract Tests', () {
    late Dio dio;
    RequestOptions? lastRequest;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://test.supabase.co'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            // Return dummy response immediately to avoid real network call
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'status': 'ok'},
              ),
            );
          },
        ),
      );
    });

    group('CustomerRemoteApi', () {
      late CustomerRemoteApi api;

      setUp(() {
        api = CustomerRemoteApi(dio);
      });

      test(
        'getCustomers issues GET /api/v1/customers with pagination',
        () async {
          await api.getCustomers(page: 1, limit: 20);

          expect(lastRequest?.method, equals('GET'));
          expect(lastRequest?.path, equals('/api/v1/customers'));
          expect(lastRequest?.queryParameters['page'], equals(1));
          expect(lastRequest?.queryParameters['limit'], equals(20));
        },
      );

      test('getCustomerById issues GET /api/v1/customers/{id}', () async {
        await api.getCustomerById('c-123');

        expect(lastRequest?.method, equals('GET'));
        expect(lastRequest?.path, equals('/api/v1/customers/c-123'));
      });

      test(
        'createCustomer issues POST /api/v1/customers with X-Operation-ID header',
        () async {
          final payload = {'name': 'Ahmed', 'phone': '01012345678'};
          await api.createCustomer('op-uuid-1', payload);

          expect(lastRequest?.method, equals('POST'));
          expect(lastRequest?.path, equals('/api/v1/customers'));
          expect(lastRequest?.headers['X-Operation-ID'], equals('op-uuid-1'));
          expect(lastRequest?.data, equals(payload));
        },
      );

      test(
        'updateCustomer issues PATCH /api/v1/customers/{id} with X-Operation-ID header',
        () async {
          final payload = {'name': 'Ahmed Updated'};
          await api.updateCustomer('op-uuid-2', 'c-123', payload);

          expect(lastRequest?.method, equals('PATCH'));
          expect(lastRequest?.path, equals('/api/v1/customers/c-123'));
          expect(lastRequest?.headers['X-Operation-ID'], equals('op-uuid-2'));
          expect(lastRequest?.data, equals(payload));
        },
      );
    });

    group('OrderRemoteApi', () {
      late OrderRemoteApi api;

      setUp(() {
        api = OrderRemoteApi(dio);
      });

      test('getOrders issues GET /api/v1/orders', () async {
        await api.getOrders(page: 2, limit: 10);

        expect(lastRequest?.method, equals('GET'));
        expect(lastRequest?.path, equals('/api/v1/orders'));
        expect(lastRequest?.queryParameters['page'], equals(2));
      });

      test(
        'createOrder issues POST /api/v1/orders with X-Operation-ID header',
        () async {
          final payload = {'customerId': 'c-1', 'total': 15000};
          await api.createOrder('op-uuid-order-create', payload);

          expect(lastRequest?.method, equals('POST'));
          expect(lastRequest?.path, equals('/api/v1/orders'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-order-create'),
          );
          expect(lastRequest?.data, equals(payload));
        },
      );

      test(
        'updateOrder issues PATCH /api/v1/orders/{id} with X-Operation-ID header',
        () async {
          final payload = {'status': 'ready'};
          await api.updateOrder('op-uuid-order-update', 'ord-123', payload);

          expect(lastRequest?.method, equals('PATCH'));
          expect(lastRequest?.path, equals('/api/v1/orders/ord-123'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-order-update'),
          );
          expect(lastRequest?.data, equals(payload));
        },
      );
    });

    group('PaymentRemoteApi', () {
      late PaymentRemoteApi api;

      setUp(() {
        api = PaymentRemoteApi(dio);
      });

      test(
        'createPayment issues POST /api/v1/payments with X-Operation-ID header',
        () async {
          final payload = {
            'orderId': 'ord-1',
            'amount': 5000,
            'paymentMethod': 'cash',
          };
          await api.createPayment('op-uuid-payment', payload);

          expect(lastRequest?.method, equals('POST'));
          expect(lastRequest?.path, equals('/api/v1/payments'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-payment'),
          );
          expect(lastRequest?.data, equals(payload));
        },
      );

      test('getPaymentById issues GET /api/v1/payments/{id}', () async {
        await api.getPaymentById('p-123');

        expect(lastRequest?.method, equals('GET'));
        expect(lastRequest?.path, equals('/api/v1/payments/p-123'));
      });
    });

    group('StorageRemoteApi', () {
      late StorageRemoteApi api;

      setUp(() {
        api = StorageRemoteApi(dio);
      });

      test(
        'createStorageRecord issues POST /api/v1/storage with X-Operation-ID header',
        () async {
          final payload = {
            'orderItemId': 'item-1',
            'storageLocationId': 'loc-1',
          };
          await api.createStorageRecord('op-uuid-storage-create', payload);

          expect(lastRequest?.method, equals('POST'));
          expect(lastRequest?.path, equals('/api/v1/storage'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-storage-create'),
          );
          expect(lastRequest?.data, equals(payload));
        },
      );

      test(
        'updateStorageRecord issues PATCH /api/v1/storage/{id} with X-Operation-ID header',
        () async {
          final payload = {'isActive': false};
          await api.updateStorageRecord(
            'op-uuid-storage-unstore',
            'rec-1',
            payload,
          );

          expect(lastRequest?.method, equals('PATCH'));
          expect(lastRequest?.path, equals('/api/v1/storage/rec-1'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-storage-unstore'),
          );
        },
      );
    });

    group('ExpenseRemoteApi', () {
      late ExpenseRemoteApi api;

      setUp(() {
        api = ExpenseRemoteApi(dio);
      });

      test(
        'createExpense issues POST /api/v1/expenses with X-Operation-ID header',
        () async {
          final payload = {'amount': 25000, 'expenseCategoryId': 'cat-1'};
          await api.createExpense('op-uuid-expense', payload);

          expect(lastRequest?.method, equals('POST'));
          expect(lastRequest?.path, equals('/api/v1/expenses'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-expense'),
          );
          expect(lastRequest?.data, equals(payload));
        },
      );

      test(
        'updateExpense issues PATCH /api/v1/expenses/{id} with X-Operation-ID header',
        () async {
          final payload = {'amount': 30000};
          await api.updateExpense('op-uuid-expense-upd', 'exp-1', payload);

          expect(lastRequest?.method, equals('PATCH'));
          expect(lastRequest?.path, equals('/api/v1/expenses/exp-1'));
          expect(
            lastRequest?.headers['X-Operation-ID'],
            equals('op-uuid-expense-upd'),
          );
        },
      );
    });

    group('MasterDataRemoteApi', () {
      late MasterDataRemoteApi api;

      setUp(() {
        api = MasterDataRemoteApi(dio);
      });

      test(
        'updateBusinessSettings issues PATCH /api/v1/business-settings',
        () async {
          final payload = {'businessName': 'Clean Laundry'};
          await api.updateBusinessSettings('op-settings', payload);

          expect(lastRequest?.method, equals('PATCH'));
          expect(lastRequest?.path, equals('/api/v1/business-settings'));
          expect(lastRequest?.headers['X-Operation-ID'], equals('op-settings'));
        },
      );

      test('expense category create and update endpoints', () async {
        await api.createExpenseCategory('op-cat-c', {'name': 'كهرباء'});
        expect(lastRequest?.method, equals('POST'));
        expect(lastRequest?.path, equals('/api/v1/expense-categories'));
        expect(lastRequest?.headers['X-Operation-ID'], equals('op-cat-c'));

        await api.updateExpenseCategory('op-cat-u', 'cat-1', {
          'isActive': false,
        });
        expect(lastRequest?.method, equals('PATCH'));
        expect(lastRequest?.path, equals('/api/v1/expense-categories/cat-1'));
        expect(lastRequest?.headers['X-Operation-ID'], equals('op-cat-u'));
      });

      test('service create and update endpoints', () async {
        await api.createService('op-srv-c', {'name': 'غسيل'});
        expect(lastRequest?.method, equals('POST'));
        expect(lastRequest?.path, equals('/api/v1/services'));

        await api.updateService('op-srv-u', 'srv-1', {'price': 5000});
        expect(lastRequest?.method, equals('PATCH'));
        expect(lastRequest?.path, equals('/api/v1/services/srv-1'));
      });

      test('item type create and update endpoints', () async {
        await api.createItemType('op-it-c', {'name': 'قميص'});
        expect(lastRequest?.method, equals('POST'));
        expect(lastRequest?.path, equals('/api/v1/item-types'));

        await api.updateItemType('op-it-u', 'it-1', {'isActive': true});
        expect(lastRequest?.method, equals('PATCH'));
        expect(lastRequest?.path, equals('/api/v1/item-types/it-1'));
      });

      test('storage location create and update endpoints', () async {
        await api.createStorageLocation('op-sl-c', {'name': 'رف 1'});
        expect(lastRequest?.method, equals('POST'));
        expect(lastRequest?.path, equals('/api/v1/storage-locations'));

        await api.updateStorageLocation('op-sl-u', 'sl-1', {'isActive': false});
        expect(lastRequest?.method, equals('PATCH'));
        expect(lastRequest?.path, equals('/api/v1/storage-locations/sl-1'));
      });
    });
  });
}
