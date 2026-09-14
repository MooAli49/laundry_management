import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  group('Dependency Injection Tests', () {
    tearDown(() async {
      await getIt.reset();
    });

    test(
      'initDependencies executes and registers core dependencies without throwing',
      () async {
        expect(getIt.isRegistered<AppDatabase>(), isFalse);

        await initDependencies();

        expect(getIt.isRegistered<AppDatabase>(), isTrue);
      },
    );
  });
}
