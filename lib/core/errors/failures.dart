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

class InvalidOrderTransitionFailure extends BusinessRuleFailure {
  final String from;
  final String to;

  InvalidOrderTransitionFailure({
    required this.from,
    required this.to,
    String? message,
  }) : super(message ?? 'Cannot transition order from $from to $to');
}

class OrderNotFullyPaidFailure extends BusinessRuleFailure {
  final String orderId;
  final num remainingAmount;

  OrderNotFullyPaidFailure({
    required this.orderId,
    required this.remainingAmount,
    String? message,
  }) : super(
          message ??
              'Order $orderId has remaining unpaid balance of $remainingAmount EGP',
        );
}

class IncompatibleServiceFailure extends BusinessRuleFailure {
  final String serviceId;
  final String itemTypeId;

  IncompatibleServiceFailure({
    required this.serviceId,
    required this.itemTypeId,
    String? message,
  }) : super(
          message ??
              'Service $serviceId is not compatible with ItemType $itemTypeId',
        );
}

class IncompatibleStorageLocationFailure extends BusinessRuleFailure {
  final String storageLocationId;
  final String itemTypeId;

  IncompatibleStorageLocationFailure({
    required this.storageLocationId,
    required this.itemTypeId,
    String? message,
  }) : super(
          message ??
              'StorageLocation $storageLocationId is not compatible with ItemType $itemTypeId',
        );
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = AppStrings.unexpectedError]);
}

