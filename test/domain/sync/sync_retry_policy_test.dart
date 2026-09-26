import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

void main() {
  group('SyncRetryPolicy Unit Tests', () {
    test('default configuration values match Phase 1 approved rules', () {
      final policy = SyncRetryPolicy();
      expect(policy.initialDelay, equals(const Duration(seconds: 5)));
      expect(policy.multiplier, equals(2.0));
      expect(policy.maxDelay, equals(const Duration(seconds: 300)));
      expect(policy.maxRetries, equals(5));
    });

    test(
      'shouldRetry permits attempts 1 through 5, and rejects attempt 6 and invalid counts',
      () {
        final policy = SyncRetryPolicy();

        expect(policy.shouldRetry(0), isFalse);
        expect(policy.shouldRetry(-1), isFalse);

        expect(policy.shouldRetry(1), isTrue);
        expect(policy.shouldRetry(2), isTrue);
        expect(policy.shouldRetry(3), isTrue);
        expect(policy.shouldRetry(4), isTrue);
        expect(policy.shouldRetry(5), isTrue);

        expect(policy.shouldRetry(6), isFalse);
        expect(policy.shouldRetry(7), isFalse);
      },
    );

    test(
      'calculateDelay produces values within exact [min, max) jitter intervals',
      () {
        final policy = SyncRetryPolicy();

        // retryCount = 1 -> in [5s, 6s)
        final delay1 = policy.calculateDelay(1);
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(5000));
        expect(delay1.inMilliseconds, lessThan(6000));

        // retryCount = 2 -> in [10s, 11s)
        final delay2 = policy.calculateDelay(2);
        expect(delay2.inMilliseconds, greaterThanOrEqualTo(10000));
        expect(delay2.inMilliseconds, lessThan(11000));

        // retryCount = 3 -> in [20s, 21s)
        final delay3 = policy.calculateDelay(3);
        expect(delay3.inMilliseconds, greaterThanOrEqualTo(20000));
        expect(delay3.inMilliseconds, lessThan(21000));

        // retryCount = 4 -> in [40s, 41s)
        final delay4 = policy.calculateDelay(4);
        expect(delay4.inMilliseconds, greaterThanOrEqualTo(40000));
        expect(delay4.inMilliseconds, lessThan(41000));

        // retryCount = 5 -> in [80s, 81s)
        final delay5 = policy.calculateDelay(5);
        expect(delay5.inMilliseconds, greaterThanOrEqualTo(80000));
        expect(delay5.inMilliseconds, lessThan(81000));
      },
    );

    test(
      'deterministic jitter injection allows exact calculation verification',
      () {
        // Inject fixed 350ms jitter
        final policy = SyncRetryPolicy(
          jitterGenerator: () => const Duration(milliseconds: 350),
        );

        expect(
          policy.calculateDelay(1),
          equals(const Duration(milliseconds: 5350)),
        );
        expect(
          policy.calculateDelay(2),
          equals(const Duration(milliseconds: 10350)),
        );
        expect(
          policy.calculateDelay(3),
          equals(const Duration(milliseconds: 20350)),
        );
        expect(
          policy.calculateDelay(4),
          equals(const Duration(milliseconds: 40350)),
        );
        expect(
          policy.calculateDelay(5),
          equals(const Duration(milliseconds: 80350)),
        );
      },
    );

    test(
      'deterministic zero jitter produces exact base exponential progression',
      () {
        final policy = SyncRetryPolicy(jitterGenerator: () => Duration.zero);

        expect(policy.calculateDelay(1), equals(const Duration(seconds: 5)));
        expect(policy.calculateDelay(2), equals(const Duration(seconds: 10)));
        expect(policy.calculateDelay(3), equals(const Duration(seconds: 20)));
        expect(policy.calculateDelay(4), equals(const Duration(seconds: 40)));
        expect(policy.calculateDelay(5), equals(const Duration(seconds: 80)));
      },
    );

    test(
      'calculateDelay throws ArgumentError when retryCount exceeds maxRetries or is invalid',
      () {
        final policy = SyncRetryPolicy();

        expect(() => policy.calculateDelay(6), throwsArgumentError);
        expect(() => policy.calculateDelay(7), throwsArgumentError);
        expect(() => policy.calculateDelay(0), throwsArgumentError);
        expect(() => policy.calculateDelay(-1), throwsArgumentError);
      },
    );

    test('maxDelay cap is strictly respected', () {
      final policy = SyncRetryPolicy(
        initialDelay: const Duration(seconds: 100),
        multiplier: 2.0,
        maxDelay: const Duration(seconds: 250),
        maxRetries: 5,
        jitterGenerator: () => Duration.zero,
      );

      // Attempt 1: 100 * 2^0 = 100s
      expect(policy.calculateDelay(1), equals(const Duration(seconds: 100)));
      // Attempt 2: 100 * 2^1 = 200s
      expect(policy.calculateDelay(2), equals(const Duration(seconds: 200)));
      // Attempt 3: 100 * 2^2 = 400s -> capped at maxDelay 250s
      expect(policy.calculateDelay(3), equals(const Duration(seconds: 250)));
      // Attempt 4: 100 * 2^3 = 800s -> capped at maxDelay 250s
      expect(policy.calculateDelay(4), equals(const Duration(seconds: 250)));
    });

    test('jitter bounds check rejects negative jitter or jitter >= 1000ms', () {
      final negativePolicy = SyncRetryPolicy(
        jitterGenerator: () => const Duration(milliseconds: -1),
      );
      expect(() => negativePolicy.calculateDelay(1), throwsStateError);

      final excessivePolicy = SyncRetryPolicy(
        jitterGenerator: () => const Duration(milliseconds: 1000),
      );
      expect(() => excessivePolicy.calculateDelay(1), throwsStateError);
    });

    test(
      'calculateNextRetryAt computes correct DateTime relative to fixed now',
      () {
        final fixedNow = DateTime.utc(2026, 9, 15, 12, 0, 0);
        final policy = SyncRetryPolicy(
          jitterGenerator: () => const Duration(milliseconds: 500),
        );

        final retryAt1 = policy.calculateNextRetryAt(1, now: fixedNow);
        expect(
          retryAt1,
          equals(fixedNow.add(const Duration(milliseconds: 5500))),
        );

        final retryAt2 = policy.calculateNextRetryAt(2, now: fixedNow);
        expect(
          retryAt2,
          equals(fixedNow.add(const Duration(milliseconds: 10500))),
        );

        final retryAtExceeded = policy.calculateNextRetryAt(6, now: fixedNow);
        expect(retryAtExceeded, isNull);
      },
    );
  });
}
