abstract class AppException implements Exception {
  final String message;
  final dynamic cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Server exception occurred',
    super.cause,
  ]);
}

class CacheException extends AppException {
  const CacheException([
    super.message = 'Cache exception occurred',
    super.cause,
  ]);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connectivity exception occurred',
    super.cause,
  ]);
}
