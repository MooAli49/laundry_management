import '../../../../domain/entities/customer.dart';

class CustomerListItemViewModel {
  final Customer customer;
  final int orderCount;

  const CustomerListItemViewModel({
    required this.customer,
    this.orderCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerListItemViewModel &&
          runtimeType == other.runtimeType &&
          customer == other.customer &&
          orderCount == other.orderCount;

  @override
  int get hashCode => Object.hash(customer, orderCount);
}
