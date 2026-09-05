import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<Customer> createCustomer(Customer customer);
  Future<Customer> updateCustomer(Customer customer);
  Future<Customer?> getCustomerById(String id);
  Future<Customer?> getCustomerByPhone(String phone);
  Future<List<Customer>> searchCustomers({String? query, int limit = 50, int offset = 0});
  Stream<List<Customer>> watchCustomers();
  Future<bool> hasOrderHistory(String customerId);
}
