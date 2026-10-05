/// Classification kind of a synchronization failure.
enum SyncFailureKind {
  /// The failure is transient (e.g. timeout, temporary server outage, rate-limiting)
  /// and should be retried according to [SyncRetryPolicy].
  retryable,

  /// The failure is deterministic/permanent (e.g. validation error, client error 4xx,
  /// authorization error, malformed payload) and must NOT be retried.
  permanent,
}

/// Abstract domain representation of transport/network-level failures.
enum SyncNetworkErrorType {
  timeout,
  noInternet,
  connectionFailed,
  dnsFailure,
  unknown,
}

/// Domain abstraction representing error details passed to [SyncErrorClassifier].
///
/// Decouples the domain layer from transport libraries such as Dio or Retrofit.
class SyncErrorDetails {
  final int? statusCode;
  final SyncNetworkErrorType? networkErrorType;
  final bool isValidationError;
  final bool isSerializationError;
  final String? message;

  const SyncErrorDetails({
    this.statusCode,
    this.networkErrorType,
    this.isValidationError = false,
    this.isSerializationError = false,
    this.message,
  });

  const SyncErrorDetails.http(int statusCode, {String? message})
    : this(statusCode: statusCode, message: message);

  const SyncErrorDetails.network(SyncNetworkErrorType type, {String? message})
    : this(networkErrorType: type, message: message);

  const SyncErrorDetails.validation({String? message})
    : this(isValidationError: true, message: message);

  const SyncErrorDetails.serialization({String? message})
    : this(isSerializationError: true, message: message);
}

/// Pure domain-level classifier that categorizes synchronization failures.
///
/// Phase 1 classification rules:
///
/// Permanent failures:
/// - HTTP 400 (Bad Request)
/// - HTTP 401 (Unauthorized / invalid API key)
/// - HTTP 403 (Forbidden)
/// - HTTP 404 (Not Found)
/// - HTTP 409 (Conflict)
/// - HTTP 422 (Unprocessable Entity / Validation failure)
/// - All other 4xx client errors
/// - Deterministic validation failures (malformed payload, invariant breach)
/// - Serialization / deserialization failures
///
/// Retryable failures:
/// - HTTP 408 (Request Timeout)
/// - HTTP 429 (Too Many Requests / Rate Limited)
/// - HTTP 500 (Internal Server Error)
/// - HTTP 502 (Bad Gateway)
/// - HTTP 503 (Service Unavailable)
/// - HTTP 504 (Gateway Timeout)
/// - All other 5xx server errors
/// - Explicit transport/network failures (timeout, connection loss, DNS error)
///
/// Unknown / unclassified failures:
/// - Classified as [SyncFailureKind.permanent] by default.
///   Rationale: In an offline-first system, retrying unclassified local runtime bugs
///   or code defects (e.g. FormatException, TypeError) will never succeed on the remote
///   server, consumes battery and network, and creates queue head-of-line blocking.
///   Only explicitly transient errors or 5xx server errors warrant automated retries.
class SyncErrorClassifier {
  const SyncErrorClassifier();

  SyncFailureKind classify(SyncErrorDetails error) {
    // 1. Explicit validation or serialization/payload errors are always permanent.
    if (error.isValidationError || error.isSerializationError) {
      return SyncFailureKind.permanent;
    }

    // 2. Explicit network/transport errors are transient and retryable.
    if (error.networkErrorType != null) {
      return SyncFailureKind.retryable;
    }

    // 3. HTTP status code classification
    final code = error.statusCode;
    if (code != null) {
      // Retryable HTTP codes: 408, 429, and any 5xx server error.
      if (code == 408 || code == 429 || (code >= 500 && code <= 599)) {
        return SyncFailureKind.retryable;
      }

      // Permanent HTTP codes: 400, 401, 403, 404, 409, 422, and all other 4xx client errors.
      if (code >= 400 && code <= 499) {
        return SyncFailureKind.permanent;
      }
    }

    // 4. Default policy for unknown/unclassified errors:
    // Safest behavior is permanent to prevent poison-pill infinite loops.
    return SyncFailureKind.permanent;
  }
}
