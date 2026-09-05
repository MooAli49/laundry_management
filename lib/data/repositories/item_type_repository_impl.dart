import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/item_type.dart';
import '../../domain/repositories/item_type_repository.dart';
import '../local/daos/item_types_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ItemTypeRepositoryImpl implements ItemTypeRepository {
  final ItemTypesDao _itemTypesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ItemTypeRepositoryImpl({
    required ItemTypesDao itemTypesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _itemTypesDao = itemTypesDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<ItemType> createItemType(ItemType itemType) async {
    try {
      return await _db.transaction(() async {
        await _itemTypesDao.insertItemType(
          app_db.ItemTypesCompanion(
            id: Value(itemType.id),
            name: Value(itemType.name),
            isActive: Value(itemType.isActive),
            createdAt: Value(itemType.createdAt),
            updatedAt: Value(itemType.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'item_type',
          entityId: itemType.id,
          operationType: 'create',
        );

        return itemType;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ItemType> updateItemType(ItemType itemType) async {
    try {
      return await _db.transaction(() async {
        final existing = await _itemTypesDao.getItemTypeById(itemType.id);
        if (existing == null) {
          throw ValidationFailure('ItemType not found');
        }

        await _itemTypesDao.updateItemType(
          app_db.ItemTypesCompanion(
            id: Value(itemType.id),
            name: Value(itemType.name),
            isActive: Value(itemType.isActive),
            createdAt: Value(itemType.createdAt),
            updatedAt: Value(itemType.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'item_type',
          entityId: itemType.id,
          operationType: 'update',
        );

        return itemType;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ItemType?> getItemTypeById(String id) async {
    try {
      final row = await _itemTypesDao.getItemTypeById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ItemType>> getActiveItemTypes() async {
    try {
      final rows = await _itemTypesDao.getActiveItemTypes();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ItemType>> getAllItemTypes() async {
    try {
      final rows = await _itemTypesDao.getAllItemTypes();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateItemType(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _itemTypesDao.getItemTypeById(id);
        if (existing == null) {
          throw ValidationFailure('ItemType not found');
        }

        await _itemTypesDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'item_type',
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
  Future<void> deactivateItemType(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _itemTypesDao.getItemTypeById(id);
        if (existing == null) {
          throw ValidationFailure('ItemType not found');
        }

        await _itemTypesDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'item_type',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  ItemType _mapToDomain(app_db.ItemType row) {
    return ItemType(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
