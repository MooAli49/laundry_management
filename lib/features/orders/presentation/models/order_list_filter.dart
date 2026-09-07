import '../../../../domain/enums/order_status.dart';

enum OrderListFilter {
  all('الكل'),
  processing('قيد التجهيز'),
  ready('جاهز'),
  completed('مكتمل'),
  cancelled('ملغي'),
  hasRemaining('يوجد مبلغ متبقي');

  final String label;
  const OrderListFilter(this.label);

  OrderStatus? get status {
    switch (this) {
      case OrderListFilter.processing:
        return OrderStatus.processing;
      case OrderListFilter.ready:
        return OrderStatus.ready;
      case OrderListFilter.completed:
        return OrderStatus.completed;
      case OrderListFilter.cancelled:
        return OrderStatus.cancelled;
      default:
        return null;
    }
  }

  bool get requiresRemainingOnly => this == OrderListFilter.hasRemaining;
}
