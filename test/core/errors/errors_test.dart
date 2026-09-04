import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/app_exception.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';

void main() {
  group('Failures & Technical Exceptions Tests', () {
    test('Failures have correct default localized messages', () {
      const serverFailure = ServerFailure();
      expect(serverFailure.message, equals(AppStrings.serverError));

      const cacheFailure = CacheFailure();
      expect(cacheFailure.message, equals(AppStrings.cacheError));

      const networkFailure = NetworkFailure();
      expect(networkFailure.message, equals(AppStrings.networkError));
    });

    test('Custom Failure messages can be provided', () {
      const customFailure = ServerFailure('خطأ مخصص في الخادم');
      expect(customFailure.message, equals('خطأ مخصص في الخادم'));
    });

    test('AppException hierarchy provides technical diagnostics', () {
      const serverException = ServerException('HTTP 500', 500);
      expect(serverException.message, equals('HTTP 500'));
      expect(serverException.cause, equals(500));
      expect(
        serverException.toString(),
        contains('ServerException: HTTP 500 (Cause: 500)'),
      );

      const cacheException = CacheException('Disk full');
      expect(cacheException.message, equals('Disk full'));
      expect(cacheException.toString(), contains('CacheException: Disk full'));

      const networkException = NetworkException('Socket timeout');
      expect(networkException.message, equals('Socket timeout'));
      expect(
        networkException.toString(),
        contains('NetworkException: Socket timeout'),
      );
    });
  });
}
