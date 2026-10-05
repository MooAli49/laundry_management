import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';

void main() {
  group('SyncErrorClassifier Unit Tests', () {
    const classifier = SyncErrorClassifier();

    group('Permanent HTTP Status Codes', () {
      const permanentCodes = [400, 401, 403, 404, 409, 422, 405, 415];

      for (final code in permanentCodes) {
        test('HTTP $code is classified as permanent', () {
          final error = SyncErrorDetails.http(code);
          expect(classifier.classify(error), equals(SyncFailureKind.permanent));
        });
      }
    });

    group('Retryable HTTP Status Codes', () {
      const retryableCodes = [408, 429, 500, 502, 503, 504, 507];

      for (final code in retryableCodes) {
        test('HTTP $code is classified as retryable', () {
          final error = SyncErrorDetails.http(code);
          expect(classifier.classify(error), equals(SyncFailureKind.retryable));
        });
      }
    });

    group('Network and Transport Failures', () {
      const networkTypes = [
        SyncNetworkErrorType.timeout,
        SyncNetworkErrorType.noInternet,
        SyncNetworkErrorType.connectionFailed,
        SyncNetworkErrorType.dnsFailure,
        SyncNetworkErrorType.unknown,
      ];

      for (final netType in networkTypes) {
        test('Network failure $netType is classified as retryable', () {
          final error = SyncErrorDetails.network(
            netType,
            message: 'Connection dropped',
          );
          expect(classifier.classify(error), equals(SyncFailureKind.retryable));
        });
      }
    });

    group('Validation and Serialization Failures', () {
      test('explicit validation failure is classified as permanent', () {
        const error = SyncErrorDetails.validation(
          message: 'Invalid customer name',
        );
        expect(classifier.classify(error), equals(SyncFailureKind.permanent));
      });

      test('explicit serialization failure is classified as permanent', () {
        const error = SyncErrorDetails.serialization(
          message: 'Malformed JSON payload',
        );
        expect(classifier.classify(error), equals(SyncFailureKind.permanent));
      });

      test(
        'validation flag takes precedence even if status code is not set',
        () {
          const error = SyncErrorDetails(isValidationError: true);
          expect(classifier.classify(error), equals(SyncFailureKind.permanent));
        },
      );

      test('serialization flag takes precedence over 5xx status code', () {
        const error = SyncErrorDetails(
          statusCode: 500,
          isSerializationError: true,
        );
        expect(classifier.classify(error), equals(SyncFailureKind.permanent));
      });
    });

    group('Unknown / Unclassified Failures', () {
      test(
        'unclassified error with no status code and no network type is classified as permanent',
        () {
          const error = SyncErrorDetails(
            message: 'Unknown unexpected exception',
          );
          expect(classifier.classify(error), equals(SyncFailureKind.permanent));
        },
      );

      test(
        'empty SyncErrorDetails defaults to permanent to avoid infinite poison-pill loops',
        () {
          const error = SyncErrorDetails();
          expect(classifier.classify(error), equals(SyncFailureKind.permanent));
        },
      );
    });
  });
}
