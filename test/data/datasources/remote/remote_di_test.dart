import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';

void main() {
  group('Remote APIs & Dispatcher DI Registration Tests', () {
    tearDown(() async {
      await GetIt.instance.reset();
    });

    test(
      'initDependencies registers all 6 Retrofit APIs and RemoteApiDispatcher',
      () async {
        await initDependencies();

        expect(GetIt.instance.isRegistered<CustomerRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<OrderRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<PaymentRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<StorageRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<ExpenseRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<MasterDataRemoteApi>(), isTrue);
        expect(GetIt.instance.isRegistered<RemoteApiDispatcher>(), isTrue);

        final dispatcher = GetIt.instance<RemoteApiDispatcher>();
        expect(dispatcher, isA<RemoteApiDispatcher>());
      },
    );
  });
}
