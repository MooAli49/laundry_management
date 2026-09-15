import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

void main() {
  group('Sync Infrastructure DI Registration Tests', () {
    setUp(() async {
      await GetIt.instance.reset();
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    test(
      'initDependencies registers SyncRetryPolicy, SyncErrorClassifier, and SyncEngine',
      () async {
        await initDependencies();

        expect(GetIt.instance.isRegistered<SyncRetryPolicy>(), isTrue);
        expect(GetIt.instance.isRegistered<SyncErrorClassifier>(), isTrue);
        expect(GetIt.instance.isRegistered<SyncEngine>(), isTrue);

        final retryPolicy = GetIt.instance<SyncRetryPolicy>();
        expect(retryPolicy, isA<SyncRetryPolicy>());

        final classifier = GetIt.instance<SyncErrorClassifier>();
        expect(classifier, isA<SyncErrorClassifier>());

        final engine = GetIt.instance<SyncEngine>();
        expect(engine, isA<SyncEngine>());
      },
    );
  });
}
