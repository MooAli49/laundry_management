import 'package:laundry_management/core/localization/app_strings.dart';

abstract class Failure implements Exception {
  final String message;

  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = AppStrings.serverError]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = AppStrings.cacheError]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = AppStrings.networkError]);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = AppStrings.cacheError]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = AppStrings.unexpectedError]);
}

