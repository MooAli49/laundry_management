import 'dart:math' as math;

/// Implementation-level backoff and retry policy for synchronization.
///
/// Approved Phase 1 rules:
/// - Initial delay: 5 seconds
/// - Multiplier: 2.0
/// - Maximum delay: 300 seconds (5 minutes)
/// - Maximum retries: 5 retries (1 initial attempt + 5 retries = 6 total attempts)
/// - Jitter: bounded additive duration in [0, 1000) ms
///
/// Progression:
/// - retryCount = 1 -> 5s + jitter
/// - retryCount = 2 -> 10s + jitter
/// - retryCount = 3 -> 20s + jitter
/// - retryCount = 4 -> 40s + jitter
/// - retryCount = 5 -> 80s + jitter
/// - retryCount >= 6 -> permanently failed / no retry allowed
class SyncRetryPolicy {
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;
  final int maxRetries;
  final Duration Function() _jitterGenerator;

  SyncRetryPolicy({
    this.initialDelay = const Duration(seconds: 5),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 300),
    this.maxRetries = 5,
    math.Random? random,
    Duration Function()? jitterGenerator,
  }) : _jitterGenerator =
           jitterGenerator ??
           (() {
             final r = random ?? math.Random();
             return Duration(milliseconds: r.nextInt(1000));
           });

  /// Returns true if an attempt with the given [retryCount] is eligible for another retry.
  ///
  /// [retryCount] is the count of failures experienced so far (1-indexed after first failure).
  /// A maximum of [maxRetries] (default 5) retries are permitted.
  bool shouldRetry(int retryCount) {
    return retryCount >= 1 && retryCount <= maxRetries;
  }

  /// Calculates the backoff delay for the given [retryCount].
  ///
  /// Throws [ArgumentError] if [retryCount] is not eligible for retry according to [shouldRetry].
  Duration calculateDelay(int retryCount) {
    if (!shouldRetry(retryCount)) {
      throw ArgumentError.value(
        retryCount,
        'retryCount',
        'Cannot calculate retry delay: retryCount exceeds maximum retries ($maxRetries)',
      );
    }

    final exponent = retryCount - 1;
    final baseSeconds = initialDelay.inSeconds * math.pow(multiplier, exponent);
    final boundedSeconds = math.min(baseSeconds, maxDelay.inSeconds.toDouble());
    final jitter = _jitterGenerator();

    if (jitter.isNegative || jitter.inMilliseconds >= 1000) {
      throw StateError('Jitter must be bounded within [0, 1000) milliseconds.');
    }

    return Duration(milliseconds: (boundedSeconds * 1000).round()) + jitter;
  }

  /// Calculates the exact timestamp for the next retry attempt relative to [now].
  ///
  /// Returns null if [shouldRetry] is false.
  DateTime? calculateNextRetryAt(int retryCount, {DateTime? now}) {
    if (!shouldRetry(retryCount)) {
      return null;
    }
    final delay = calculateDelay(retryCount);
    return (now ?? DateTime.now()).add(delay);
  }
}
