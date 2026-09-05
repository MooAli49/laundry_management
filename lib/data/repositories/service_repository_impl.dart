import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/service.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/value_objects/money.dart';
import '../local/daos/services_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ServiceRepositoryImpl implements ServiceRepository {
  final ServicesDao _servicesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ServiceRepositoryImpl({
    required ServicesDao servicesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _servicesDao = servicesDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Service> createService(
    Service service, {
    required List<String> supportedItemTypeIds,
  }) async {
    try {
      return await _db.transaction(() async {
        await _servicesDao.insertService(
          app_db.ServicesCompanion(
            id: Value(service.id),
            name: Value(service.name),
            description: Value(service.description),
            pricingType: Value(service.pricingType.name),
            price: Value(service.price.piastres),
            isActive: Value(service.isActive),
            createdAt: Value(service.createdAt),
            updatedAt: Value(service.updatedAt),
          ),
        );

        if (supportedItemTypeIds.isNotEmpty) {
          await _servicesDao.replaceSupportedItemTypes(
            service.id,
            supportedItemTypeIds,
          );
        }

        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: service.id,
          operationType: 'create',
        );

        return service;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Service> updateService(
    Service service, {
    List<String>? supportedItemTypeIds,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await _servicesDao.getServiceById(service.id);
        if (existing == null) {
          throw ValidationFailure('Service not found');
        }

        await _servicesDao.updateService(
          app_db.ServicesCompanion(
            id: Value(service.id),
            name: Value(service.name),
            description: Value(service.description),
            pricingType: Value(service.pricingType.name),
            price: Value(service.price.piastres),
            isActive: Value(service.isActive),
            createdAt: Value(service.createdAt),
            updatedAt: Value(service.updatedAt),
          ),
        );

        if (supportedItemTypeIds != null) {
          await _servicesDao.replaceSupportedItemTypes(
            service.id,
            supportedItemTypeIds,
          );
        }

        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: service.id,
          operationType: 'update',
        );

        return service;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Service?> getServiceById(String id) async {
    try {
      final row = await _servicesDao.getServiceById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Service>> getActiveServices() async {
    try {
      final rows = await _servicesDao.getActiveServices();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Service>> getAllServices() async {
    try {
      final rows = await _servicesDao.getAllServices();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Service>> getServicesForItemType(String itemTypeId) async {
    try {
      final rows = await _servicesDao.getServicesForItemType(itemTypeId);
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateService(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _servicesDao.getServiceById(id);
        if (existing == null) {
          throw ValidationFailure('Service not found');
        }

        await _servicesDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: id,
          operationType: 'activate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> deactivateService(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _servicesDao.getServiceById(id);
        if (existing == null) {
          throw ValidationFailure('Service not found');
        }

        await _servicesDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  Service _mapToDomain(app_db.Service row) {
    return Service(
      id: row.id,
      name: row.name,
      description: row.description,
      pricingType: PricingType.values.byName(row.pricingType),
      price: Money.fromPiastres(row.price),
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
