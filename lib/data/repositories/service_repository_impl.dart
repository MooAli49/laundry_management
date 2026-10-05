import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/service.dart';
import '../../domain/entities/service_item_type.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/models/service_with_pricing.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/value_objects/money.dart';
import '../local/daos/services_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;
import '../sync/sync_payload_builder.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final ServicesDao _servicesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ServiceRepositoryImpl({
    required ServicesDao servicesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  }) : _servicesDao = servicesDao,
       _syncOperationsDao = syncOperationsDao,
       _db = db;

  @override
  Future<Service> createService(
    Service service, {
    required List<ServiceItemType> serviceItemTypes,
  }) async {
    try {
      return await _db.transaction(() async {
        await _servicesDao.insertService(
          app_db.ServicesCompanion(
            id: Value(service.id),
            name: Value(service.name),
            description: Value(service.description),
            isActive: Value(service.isActive),
            createdAt: Value(service.createdAt),
            updatedAt: Value(service.updatedAt),
          ),
        );

        final companions = serviceItemTypes
            .map(
              (sit) => app_db.ServiceItemTypesCompanion(
                id: Value(sit.id),
                serviceId: Value(service.id),
                itemTypeId: Value(sit.itemTypeId),
                pricingType: Value(sit.pricingType.value),
                price: Value(sit.price.piastres),
                createdAt: Value(sit.createdAt),
                updatedAt: Value(sit.updatedAt),
              ),
            )
            .toList();

        await _servicesDao.replaceServiceItemTypes(service.id, companions);

        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: service.id,
          operationType: 'create',
          payload: SyncPayloadBuilder.buildServicePayload(
            service,
            serviceItemTypes,
          ),
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
    List<ServiceItemType>? serviceItemTypes,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await _servicesDao.getServiceById(service.id);
        if (existing == null) {
          throw const ValidationFailure('Service not found');
        }

        await _servicesDao.updateService(
          app_db.ServicesCompanion(
            id: Value(service.id),
            name: Value(service.name),
            description: Value(service.description),
            isActive: Value(service.isActive),
            createdAt: Value(service.createdAt),
            updatedAt: Value(service.updatedAt),
          ),
        );

        List<ServiceItemType> finalConfigs;
        if (serviceItemTypes != null) {
          final existingRows = await _servicesDao.getServiceItemTypes(
            service.id,
          );
          final existingByItemTypeId = {
            for (final r in existingRows) r.itemTypeId: r,
          };

          final companions = serviceItemTypes
              .map(
                (sit) {
                  final existing = existingByItemTypeId[sit.itemTypeId];
                  final idToUse = sit.id.isNotEmpty
                      ? sit.id
                      : (existing?.id ?? const Uuid().v4());
                  return app_db.ServiceItemTypesCompanion(
                    id: Value(idToUse),
                    serviceId: Value(service.id),
                    itemTypeId: Value(sit.itemTypeId),
                    pricingType: Value(sit.pricingType.value),
                    price: Value(sit.price.piastres),
                    createdAt: Value(existing?.createdAt ?? sit.createdAt),
                    updatedAt: Value(sit.updatedAt),
                  );
                },
              )
              .toList();
          await _servicesDao.replaceServiceItemTypes(service.id, companions);
          finalConfigs = serviceItemTypes;
        } else {
          final existingRows = await _servicesDao.getServiceItemTypes(
            service.id,
          );
          finalConfigs = existingRows.map(_mapSitToDomain).toList();
        }

        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: service.id,
          operationType: 'update',
          payload: SyncPayloadBuilder.buildServicePayload(service, finalConfigs),
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
  Future<List<ServiceWithPricing>> getServicesForItemType(
    String itemTypeId,
  ) async {
    try {
      final rows = await _servicesDao.getServicesWithPricingForItemType(
        itemTypeId,
      );
      return rows
          .map(
            (r) => ServiceWithPricing(
              service: _mapToDomain(r.service),
              serviceItemType: _mapSitToDomain(r.serviceItemType),
            ),
          )
          .toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ServiceItemType?> getServiceItemType(
    String serviceId,
    String itemTypeId,
  ) async {
    try {
      final row = await _servicesDao.getServiceItemType(serviceId, itemTypeId);
      return row != null ? _mapSitToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ServiceItemType>> getServiceItemTypes(String serviceId) async {
    try {
      final rows = await _servicesDao.getServiceItemTypes(serviceId);
      return rows.map(_mapSitToDomain).toList();
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
          throw const ValidationFailure('Service not found');
        }

        final now = DateTime.now();
        await _servicesDao.setActiveStatus(id, true, now);
        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: id,
          operationType: 'activate',
          payload: SyncPayloadBuilder.buildServiceStatusPayload(
            id,
            true,
            updatedAt: now,
          ),
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
          throw const ValidationFailure('Service not found');
        }

        final now = DateTime.now();
        await _servicesDao.setActiveStatus(id, false, now);
        await _syncOperationsDao.recordOperation(
          entityType: 'service',
          entityId: id,
          operationType: 'deactivate',
          payload: SyncPayloadBuilder.buildServiceStatusPayload(
            id,
            false,
            updatedAt: now,
          ),
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<String>> getSupportedItemTypeIds(String serviceId) async {
    try {
      return await _servicesDao.getSupportedItemTypeIds(serviceId);
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
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ServiceItemType _mapSitToDomain(app_db.ServiceItemType row) {
    return ServiceItemType(
      id: row.id,
      serviceId: row.serviceId,
      itemTypeId: row.itemTypeId,
      pricingType: PricingType.fromValue(row.pricingType),
      price: Money.fromPiastres(row.price),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
