import '../../../../domain/entities/dashboard_order_item.dart';

enum RecordPaymentStep {
  selectOrder,
  enterPayment,
}

class RecordPaymentState {
  final RecordPaymentStep step;
  final bool isLoadingOrders;
  final List<DashboardOrderItem> orders;
  final DashboardOrderItem? selectedOrder;
  final bool isRecordingPayment;
  final bool isPaymentSuccess;
  final String? errorMessage;

  const RecordPaymentState({
    this.step = RecordPaymentStep.selectOrder,
    this.isLoadingOrders = false,
    this.orders = const [],
    this.selectedOrder,
    this.isRecordingPayment = false,
    this.isPaymentSuccess = false,
    this.errorMessage,
  });

  RecordPaymentState copyWith({
    RecordPaymentStep? step,
    bool? isLoadingOrders,
    List<DashboardOrderItem>? orders,
    DashboardOrderItem? selectedOrder,
    bool clearSelectedOrder = false,
    bool? isRecordingPayment,
    bool? isPaymentSuccess,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RecordPaymentState(
      step: step ?? this.step,
      isLoadingOrders: isLoadingOrders ?? this.isLoadingOrders,
      orders: orders ?? this.orders,
      selectedOrder: clearSelectedOrder ? null : (selectedOrder ?? this.selectedOrder),
      isRecordingPayment: isRecordingPayment ?? this.isRecordingPayment,
      isPaymentSuccess: isPaymentSuccess ?? this.isPaymentSuccess,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
