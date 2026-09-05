import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/repositories/storage_location_repository.dart';
import '../local/daos/storage_locations_dao.dart';
import '../local/daos/storage_records_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class StorageLocationRepositoryImpl implements StorageLocationRepository {
  final StorageLocationsDao _storageLocationsDao;
  final StorageRecordsDao _storageRecordsDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  StorageLocationRepositoryImpl({
    required StorageLocationsDao storageLocationsDao,
    required StorageRecordsDao storageRecordsDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _storageLocationsDao = storageLocationsDao,
        _storageRecordsDao = storageRecordsDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<StorageLocation> createStorageLocation(
    StorageLocation location, {
    required List<String> supportedItemTypeIds,
  }) async {
    try {
      return await _db.transaction(() async {
        await _storageLocationsDao.insertLocation(
          app_db.StorageLocationsCompanion(
            id: Value(location.id),
            name: Value(location.name),
            isActive: Value(location.isActive),
            createdAt: Value(location.createdAt),
            updatedAt: Value(location.updatedAt),
          ),
        );

        if (supportedItemTypeIds.isNotEmpty) {
          await _storageLocationsDao.replaceSupportedItemTypes(
            location.id,
            supportedItemTypeIds,
          );
        }

        await _syncOperationsDao.recordOperation(
          entityType: 'storage_location',
          entityId: location.id,
          operationType: 'create',
        );

        return location;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<StorageLocation> updateStorageLocation(
    StorageLocation location, {
    List<String>? supportedItemTypeIds,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await _storageLocationsDao.getLocationById(location.id);
        if (existing == null) {
          throw ValidationFailure('Storage location not found');
        }

        await _storageLocationsDao.updateLocation(
          app_db.StorageLocationsCompanion(
            id: Value(location.id),
            name: Value(location.name),
            isActive: Value(location.isActive),
            createdAt: Value(location.createdAt),
            updatedAt: Value(location.updatedAt),
          ),
        );

        if (supportedItemTypeIds != null) {
          await _storageLocationsDao.replaceSupportedItemTypes(
            location.id,
            supportedItemTypeIds,
          );
        }

        await _syncOperationsDao.recordOperation(
          entityType: 'storage_location',
          entityId: location.id,
          operationType: 'update',
        );

        return location;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<StorageLocation?> getStorageLocationById(String id) async {
    try {
      final row = await _storageLocationsDao.getLocationById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageLocation>> getActiveLocations() async {
    try {
      final rows = await _storageLocationsDao.getActiveLocations();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageLocation>> getAllLocations() async {
    try {
      final rows = await _storageLocationsDao.getAllLocations();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId) async {
    try {
      final rows = await _storageLocationsDao.getCompatibleLocationsForItemType(itemTypeId);
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateStorageLocation(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _storageLocationsDao.getLocationById(id);
        if (existing == null) {
          throw ValidationFailure('Storage location not found');
        }

        await _storageLocationsDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'storage_location',
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
  Future<void> deactivateStorageLocation(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _storageLocationsDao.getLocationById(id);
        if (existing == null) {
          throw ValidationFailure('Storage location not found');
        }

        final activeStored = await _storageRecordsDao.getActiveRecordsForLocation(id);
        if (activeStored.isNotEmpty) {
          throw BusinessRuleFailure(
            'Cannot deactivate storage location while items are stored in it',
          );
        }

        await _storageLocationsDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'storage_location',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  StorageLocation _mapToDomain(app_db.StorageLocation row) {
    return StorageLocation(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
