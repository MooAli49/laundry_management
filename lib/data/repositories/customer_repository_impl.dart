import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../local/daos/customers_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomersDao _customersDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  CustomerRepositoryImpl({
    required CustomersDao customersDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _customersDao = customersDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Customer> createCustomer(Customer customer) async {
    try {
      return await _db.transaction(() async {
        await _customersDao.insertCustomer(
          app_db.CustomersCompanion(
            id: Value(customer.id),
            name: Value(customer.name),
            phone: Value(customer.phone),
            notes: Value(customer.notes),
            createdAt: Value(customer.createdAt),
            updatedAt: Value(customer.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: customer.id,
          operationType: 'create',
        );

        return customer;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    try {
      return await _db.transaction(() async {
        final existing = await _customersDao.getCustomerById(customer.id);
        if (existing == null) {
          throw ValidationFailure('Customer with id ${customer.id} not found');
        }

        await _customersDao.updateCustomer(
          app_db.CustomersCompanion(
            id: Value(customer.id),
            name: Value(customer.name),
            phone: Value(customer.phone),
            notes: Value(customer.notes),
            createdAt: Value(customer.createdAt),
            updatedAt: Value(customer.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: customer.id,
          operationType: 'update',
        );

        return customer;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    try {
      final row = await _customersDao.getCustomerById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final row = await _customersDao.getCustomerByPhone(phone);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Customer>> searchCustomers({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _customersDao.searchCustomers(
        query: query,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<Customer>> watchCustomers() {
    try {
      return _customersDao.watchCustomers().map(
            (rows) => rows.map(_mapToDomain).toList(),
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<bool> hasOrderHistory(String customerId) async {
    try {
      return await _customersDao.hasOrderHistory(customerId);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  Customer _mapToDomain(app_db.Customer row) {
    return Customer(
      id: row.id,
      name: row.name,
      phone: row.phone,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
