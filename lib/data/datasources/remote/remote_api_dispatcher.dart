import 'dart:convert';

import '../../local/database/app_database.dart';
import 'customer_remote_api.dart';
import 'expense_remote_api.dart';
import 'master_data_remote_api.dart';
import 'order_remote_api.dart';
import 'payment_remote_api.dart';
import 'refund_remote_api.dart';
import 'storage_remote_api.dart';

/// Translates a persisted [SyncOperation] into the corresponding typed Retrofit API call.
///
/// Dispatches based on [SyncOperation.entityType] and [SyncOperation.operationType],
/// preserving the stable [SyncOperation.id] as the `X-Operation-ID` header for remote idempotency.
///
/// Does NOT manage retries, backoff, queue updates, or database access.
/// Propagates all remote exceptions directly to caller.
class RemoteApiDispatcher {
  final CustomerRemoteApi _customerApi;
  final OrderRemoteApi _orderApi;
  final PaymentRemoteApi _paymentApi;
  final RefundRemoteApi _refundApi;
  final StorageRemoteApi _storageApi;
  final ExpenseRemoteApi _expenseApi;
  final MasterDataRemoteApi _masterDataApi;

  RemoteApiDispatcher({
    required CustomerRemoteApi customerApi,
    required OrderRemoteApi orderApi,
    required PaymentRemoteApi paymentApi,
    required RefundRemoteApi refundApi,
    required StorageRemoteApi storageApi,
    required ExpenseRemoteApi expenseApi,
    required MasterDataRemoteApi masterDataApi,
  }) : _customerApi = customerApi,
       _orderApi = orderApi,
       _paymentApi = paymentApi,
       _refundApi = refundApi,
       _storageApi = storageApi,
       _expenseApi = expenseApi,
       _masterDataApi = masterDataApi;

  /// Dispatches the [operation] to the appropriate typed Retrofit endpoint.
  ///
  /// Throws [UnsupportedError] if the entity type or operation type is unsupported.
  /// Allows network / Dio exceptions to propagate without swallowing.
  Future<dynamic> dispatch(SyncOperation operation) async {
    final payload = _extractPayload(operation);
    final opId = operation.id;
    final entityId = operation.entityId;

    switch (operation.entityType) {
      case 'customer':
        return _dispatchCustomer(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'order':
        return _dispatchOrder(opId, entityId, operation.operationType, payload);

      case 'payment':
        return _dispatchPayment(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'refund':
        return _dispatchRefund(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'storage_record':
        return _dispatchStorage(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'expense':
        return _dispatchExpense(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'expense_category':
        return _dispatchExpenseCategory(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'service':
        return _dispatchService(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'service_item_type':
        return _dispatchServiceItemType(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'item_type':
        return _dispatchItemType(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'item_definition':
        return _dispatchItemDefinition(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'carpet_size':
        return _dispatchCarpetSize(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'storage_location':
        return _dispatchStorageLocation(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      case 'business_settings':
        return _dispatchBusinessSettings(
          opId,
          entityId,
          operation.operationType,
          payload,
        );

      default:
        throw UnsupportedError(
          'Unsupported sync entity type: ${operation.entityType}',
        );
    }
  }

  // ===========================================================================
  // Entity Handlers
  // ===========================================================================

  Future<dynamic> _dispatchCustomer(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _customerApi.createCustomer(opId, payload);
      case 'update':
        return _customerApi.updateCustomer(opId, entityId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "customer"',
        );
    }
  }

  Future<dynamic> _dispatchOrder(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _orderApi.createOrder(opId, payload);
      case 'update':
        return _orderApi.updateOrder(opId, entityId, payload);
      case 'edit':
        return _orderApi.editOrderAggregate(opId, entityId, payload);
      case 'mark_ready':
        return _orderApi.updateOrder(opId, entityId, {
          'status': 'ready',
          ...payload,
        });
      case 'complete':
        return _orderApi.updateOrder(opId, entityId, {
          'status': 'completed',
          ...payload,
        });
      case 'cancel':
        return _orderApi.updateOrder(opId, entityId, {
          'status': 'cancelled',
          ...payload,
        });
      case 'status_correction':
        return _orderApi.updateOrder(opId, entityId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "order"',
        );
    }
  }

  Future<dynamic> _dispatchPayment(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _paymentApi.createPayment(opId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "payment"',
        );
    }
  }

  Future<dynamic> _dispatchRefund(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _refundApi.createRefund(opId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "refund"',
        );
    }
  }

  Future<dynamic> _dispatchStorage(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _storageApi.createStorageRecord(opId, payload);
      case 'move':
        return _storageApi.updateStorageRecord(opId, entityId, payload);
      case 'unstore':
        return _storageApi.updateStorageRecord(opId, entityId, {
          'is_active': false,
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "storage_record"',
        );
    }
  }

  Future<dynamic> _dispatchExpense(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _expenseApi.createExpense(opId, payload);
      case 'update':
        return _expenseApi.updateExpense(opId, entityId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "expense"',
        );
    }
  }

  Future<dynamic> _dispatchExpenseCategory(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createExpenseCategory(opId, payload);
      case 'update':
        return _masterDataApi.updateExpenseCategory(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateExpenseCategory(opId, entityId, {
          'is_active': true,
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateExpenseCategory(opId, entityId, {
          'is_active': false,
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "expense_category"',
        );
    }
  }

  Future<dynamic> _dispatchService(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createService(opId, payload);
      case 'update':
        return _masterDataApi.updateService(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateService(opId, entityId, {
          'is_active': true,
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateService(opId, entityId, {
          'is_active': false,
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "service"',
        );
    }
  }

  Future<dynamic> _dispatchServiceItemType(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createServiceItemType(opId, payload);
      case 'update':
        return _masterDataApi.updateServiceItemType(opId, entityId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "service_item_type"',
        );
    }
  }

  Future<dynamic> _dispatchItemType(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createItemType(opId, payload);
      case 'update':
        return _masterDataApi.updateItemType(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateItemType(opId, entityId, {
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateItemType(opId, entityId, {
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "item_type"',
        );
    }
  }

  Future<dynamic> _dispatchItemDefinition(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createItemDefinition(opId, payload);
      case 'update':
        return _masterDataApi.updateItemDefinition(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateItemDefinition(opId, entityId, {
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateItemDefinition(opId, entityId, {
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "item_definition"',
        );
    }
  }

  Future<dynamic> _dispatchCarpetSize(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createCarpetSize(opId, payload);
      case 'update':
        return _masterDataApi.updateCarpetSize(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateCarpetSize(opId, entityId, {
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateCarpetSize(opId, entityId, {
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "carpet_size"',
        );
    }
  }

  Future<dynamic> _dispatchStorageLocation(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'create':
        return _masterDataApi.createStorageLocation(opId, payload);
      case 'update':
        return _masterDataApi.updateStorageLocation(opId, entityId, payload);
      case 'activate':
        return _masterDataApi.updateStorageLocation(opId, entityId, {
          'isActive': true,
          ...payload,
        });
      case 'deactivate':
        return _masterDataApi.updateStorageLocation(opId, entityId, {
          'isActive': false,
          ...payload,
        });
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "storage_location"',
        );
    }
  }

  Future<dynamic> _dispatchBusinessSettings(
    String opId,
    String entityId,
    String opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case 'update':
        return _masterDataApi.updateBusinessSettings(opId, payload);
      default:
        throw UnsupportedError(
          'Unsupported operation "$opType" for entity "business_settings"',
        );
    }
  }

  // ===========================================================================
  // Payload Helper
  // ===========================================================================

  Map<String, dynamic> _extractPayload(SyncOperation operation) {
    if (operation.payload == null || operation.payload!.trim().isEmpty) {
      return <String, dynamic>{'id': operation.entityId};
    }
    try {
      final decoded = jsonDecode(operation.payload!);
      if (decoded is Map<String, dynamic>) {
        decoded.putIfAbsent('id', () => operation.entityId);
        return decoded;
      } else {
        return <String, dynamic>{'id': operation.entityId, 'value': decoded};
      }
    } on FormatException {
      return <String, dynamic>{
        'id': operation.entityId,
        'reason': operation.payload,
      };
    }
  }
}
