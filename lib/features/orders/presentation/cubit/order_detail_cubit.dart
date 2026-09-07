import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../application/use_cases/cancel_order_use_case.dart';
import '../../../../application/use_cases/change_order_status_use_case.dart';
import '../../../../application/use_cases/complete_order_use_case.dart';
import '../../../../application/use_cases/store_order_items_use_case.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/entities/storage_record.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/repositories/storage_location_repository.dart';
import '../../../../domain/repositories/storage_repository.dart';
import '../../../../domain/value_objects/money.dart';
import 'order_detail_state.dart';

class OrderDetailCubit extends Cubit<OrderDetailState> {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final PaymentRepository _paymentRepository;
  final StorageRepository _storageRepository;
  final StorageLocationRepository _storageLocationRepository;
  final SettingsRepository _settingsRepository;
  final StoreOrderItemsUseCase _storeOrderItemsUseCase;
  final ChangeOrderStatusUseCase _changeOrderStatusUseCase;
  final CompleteOrderUseCase _completeOrderUseCase;
  final CancelOrderUseCase _cancelOrderUseCase;
  final Uuid _uuid;

  OrderDetailCubit({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required PaymentRepository paymentRepository,
    required StorageRepository storageRepository,
    required StorageLocationRepository storageLocationRepository,
    required SettingsRepository settingsRepository,
    required StoreOrderItemsUseCase storeOrderItemsUseCase,
    required ChangeOrderStatusUseCase changeOrderStatusUseCase,
    required CompleteOrderUseCase completeOrderUseCase,
    required CancelOrderUseCase cancelOrderUseCase,
    Uuid? uuid,
  })  : _orderRepository = orderRepository,
        _customerRepository = customerRepository,
        _paymentRepository = paymentRepository,
        _storageRepository = storageRepository,
        _storageLocationRepository = storageLocationRepository,
        _settingsRepository = settingsRepository,
        _storeOrderItemsUseCase = storeOrderItemsUseCase,
        _changeOrderStatusUseCase = changeOrderStatusUseCase,
        _completeOrderUseCase = completeOrderUseCase,
        _cancelOrderUseCase = cancelOrderUseCase,
        _uuid = uuid ?? const Uuid(),
        super(const OrderDetailState());

  Future<void> loadOrderDetail(String orderId) async {
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearActionSuccessMessage: true,
    ));

    try {
      final order = await _orderRepository.getOrderById(orderId);
      if (order == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'الطلب غير موجود',
        ));
        return;
      }

      final customer = await _customerRepository.getCustomerById(order.customerId);
      final items = await _orderRepository.getOrderItems(orderId);
      final payments = await _paymentRepository.getPaymentsForOrder(orderId);
      final totalPaid = await _paymentRepository.getTotalPaidForOrder(orderId);
      final remaining = await _paymentRepository.getRemainingAmountForOrder(orderId);
      final settings = await _settingsRepository.getSettings();
      final allActiveLocations = await _storageLocationRepository.getActiveLocations();

      final activeStorageRecords = <String, StorageRecord>{};
      final locationMap = <String, StorageLocation>{};

      for (final loc in allActiveLocations) {
        locationMap[loc.id] = loc;
      }

      for (final item in items) {
        final record = await _storageRepository.getActiveRecordForOrderItem(item.id);
        if (record != null) {
          activeStorageRecords[item.id] = record;
          if (!locationMap.containsKey(record.storageLocationId)) {
            final loc = await _storageLocationRepository.getStorageLocationById(record.storageLocationId);
            if (loc != null) {
              locationMap[loc.id] = loc;
            }
          }
        }
      }

      emit(state.copyWith(
        isLoading: false,
        order: order,
        customer: customer,
        items: items,
        activeStorageRecords: activeStorageRecords,
        storageLocations: locationMap,
        allActiveLocations: allActiveLocations,
        payments: payments,
        totalPaid: totalPaid,
        remainingAmount: remaining,
        settings: settings,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> recordPayment({
    required Money amount,
    required PaymentMethod method,
  }) async {
    final order = state.order;
    if (order == null) return;

    if (amount <= Money.zero) {
      emit(state.copyWith(errorMessage: 'مبلغ الدفعة يجب أن يكون أكبر من الصفر'));
      return;
    }
    if (amount > state.remainingAmount) {
      emit(state.copyWith(errorMessage: 'مبلغ الدفعة يتجاوز المبلغ المتبقي على الطلب'));
      return;
    }

    emit(state.copyWith(isActionLoading: true, clearErrorMessage: true, clearActionSuccessMessage: true));

    try {
      final now = DateTime.now();
      final payment = Payment(
        id: _uuid.v4(),
        orderId: order.id,
        amount: amount,
        paymentMethod: method,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await _paymentRepository.recordPayment(payment);
      await loadOrderDetail(order.id);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'تم تسجيل الدفعة بنجاح',
      ));
    } on Failure catch (f) {
      emit(state.copyWith(isActionLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isActionLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> storeItems({
    required List<String> orderItemIds,
    required String storageLocationId,
  }) async {
    final order = state.order;
    if (order == null) return;

    if (orderItemIds.isEmpty) {
      emit(state.copyWith(errorMessage: 'يرجى تحديد قطعة واحدة على الأقل للتخزين'));
      return;
    }

    emit(state.copyWith(isActionLoading: true, clearErrorMessage: true, clearActionSuccessMessage: true));

    try {
      await _storeOrderItemsUseCase.execute(
        StoreOrderItemsInput(
          orderId: order.id,
          orderItemIds: orderItemIds,
          storageLocationId: storageLocationId,
        ),
      );

      await loadOrderDetail(order.id);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'تم تخزين العناصر بنجاح',
      ));
    } on Failure catch (f) {
      emit(state.copyWith(isActionLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isActionLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> changeStatus({
    required OrderStatus newStatus,
    String? reason,
  }) async {
    final order = state.order;
    if (order == null) return;

    if (newStatus == OrderStatus.completed) {
      emit(state.copyWith(
        errorMessage: 'إكمال الطلب يتطلب التحقق من الدفع والاستلام. يرجى استخدام زر "إكمال الطلب".',
      ));
      return;
    }

    emit(state.copyWith(isActionLoading: true, clearErrorMessage: true, clearActionSuccessMessage: true));

    try {
      await _changeOrderStatusUseCase.execute(
        ChangeOrderStatusInput(
          orderId: order.id,
          newStatus: newStatus,
          reason: reason,
        ),
      );

      await loadOrderDetail(order.id);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'تم تحديث حالة الطلب بنجاح',
      ));
    } on Failure catch (f) {
      emit(state.copyWith(isActionLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isActionLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> completeOrder({required bool handoverConfirmed}) async {
    final order = state.order;
    if (order == null) return;

    if (!handoverConfirmed) {
      emit(state.copyWith(errorMessage: 'يجب تأكيد تسليم الملابس للعميل أولاً'));
      return;
    }
    if (order.status != OrderStatus.ready) {
      emit(state.copyWith(errorMessage: 'يمكن إكمال الطلبات في حالة "جاهز" فقط'));
      return;
    }
    if (state.remainingAmount > Money.zero) {
      emit(state.copyWith(
        errorMessage: 'لا يمكن إكمال الطلب قبل سداد كامل المبلغ المتبقي (${state.remainingAmount.toEgp} ج.م)',
      ));
      return;
    }

    emit(state.copyWith(isActionLoading: true, clearErrorMessage: true, clearActionSuccessMessage: true));

    try {
      await _completeOrderUseCase.execute(
        CompleteOrderInput(
          orderId: order.id,
          handoverConfirmed: handoverConfirmed,
        ),
      );

      await loadOrderDetail(order.id);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'تم إكمال الطلب وتسليمه للعميل بنجاح',
      ));
    } on Failure catch (f) {
      emit(state.copyWith(isActionLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isActionLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> cancelOrder({required String cancellationReason}) async {
    final order = state.order;
    if (order == null) return;

    final trimmed = cancellationReason.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: 'سبب الإلغاء مطلوب'));
      return;
    }

    emit(state.copyWith(isActionLoading: true, clearErrorMessage: true, clearActionSuccessMessage: true));

    try {
      await _cancelOrderUseCase.execute(
        CancelOrderInput(
          orderId: order.id,
          cancellationReason: trimmed,
          confirmed: true,
        ),
      );

      await loadOrderDetail(order.id);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'تم إلغاء الطلب بنجاح',
      ));
    } on Failure catch (f) {
      emit(state.copyWith(isActionLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isActionLoading: false, errorMessage: e.toString()));
    }
  }
}
