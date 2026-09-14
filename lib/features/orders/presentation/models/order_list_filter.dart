import '../../../../domain/enums/order_status.dart';

enum OrderListFilter {
  all('الكل'),
  today('طلبات اليوم'),
  processing('قيد التجهيز'),
  ready('جاهز'),
  todayPickup('استلام اليوم'),
  overdue('طلبات متأخرة'),
  hasRemaining('يوجد مبلغ متبقي'),
  completed('مكتمل'),
  cancelled('ملغي');

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
  bool get requiresTodayOnly => this == OrderListFilter.today;
  bool get requiresTodayPickupOnly => this == OrderListFilter.todayPickup;
  bool get requiresOverdueOnly => this == OrderListFilter.overdue;

  static OrderListFilter fromString(String? val) {
    if (val == null) return OrderListFilter.all;
    for (final f in OrderListFilter.values) {
      if (f.name == val) return f;
    }
    return OrderListFilter.all;
  }
}
