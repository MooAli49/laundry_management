abstract class Failure {
  final String message;

  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'حدث خطأ في الاتصال بالخادم']);
}

class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'حدث خطأ في الوصول إلى البيانات المحلية',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'يرجى التحقق من الاتصال بالإنترنت']);
}
