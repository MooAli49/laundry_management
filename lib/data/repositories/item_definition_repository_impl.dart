import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/repositories/item_definition_repository.dart';
import '../local/daos/item_definitions_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ItemDefinitionRepositoryImpl implements ItemDefinitionRepository {
  final ItemDefinitionsDao _itemDefinitionsDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ItemDefinitionRepositoryImpl({
    required ItemDefinitionsDao itemDefinitionsDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _itemDefinitionsDao = itemDefinitionsDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<ItemDefinition> createItemDefinition(ItemDefinition itemDefinition) async {
    try {
      return await _db.transaction(() async {
        await _itemDefinitionsDao.insertItemDefinition(
          app_db.ItemDefinitionsCompanion(
            id: Value(itemDefinition.id),
            itemTypeId: Value(itemDefinition.itemTypeId),
            name: Value(itemDefinition.name),
            isActive: Value(itemDefinition.isActive),
            createdAt: Value(itemDefinition.createdAt),
            updatedAt: Value(itemDefinition.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'item_definition',
          entityId: itemDefinition.id,
          operationType: 'create',
        );

        return itemDefinition;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ItemDefinition> updateItemDefinition(ItemDefinition itemDefinition) async {
    try {
      return await _db.transaction(() async {
        final existing = await _itemDefinitionsDao.getItemDefinitionById(itemDefinition.id);
        if (existing == null) {
          throw ValidationFailure('ItemDefinition not found');
        }

        await _itemDefinitionsDao.updateItemDefinition(
          app_db.ItemDefinitionsCompanion(
            id: Value(itemDefinition.id),
            itemTypeId: Value(itemDefinition.itemTypeId),
            name: Value(itemDefinition.name),
            isActive: Value(itemDefinition.isActive),
            createdAt: Value(itemDefinition.createdAt),
            updatedAt: Value(itemDefinition.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'item_definition',
          entityId: itemDefinition.id,
          operationType: 'update',
        );

        return itemDefinition;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ItemDefinition?> getItemDefinitionById(String id) async {
    try {
      final row = await _itemDefinitionsDao.getItemDefinitionById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ItemDefinition>> getDefinitionsForItemType(
    String itemTypeId, {
    bool activeOnly = true,
  }) async {
    try {
      final rows = await _itemDefinitionsDao.getDefinitionsForItemType(
        itemTypeId,
        activeOnly: activeOnly,
      );
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ItemDefinition>> getAllDefinitions() async {
    try {
      final rows = await _itemDefinitionsDao.getAllDefinitions();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateItemDefinition(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _itemDefinitionsDao.getItemDefinitionById(id);
        if (existing == null) {
          throw ValidationFailure('ItemDefinition not found');
        }

        await _itemDefinitionsDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'item_definition',
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
  Future<void> deactivateItemDefinition(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _itemDefinitionsDao.getItemDefinitionById(id);
        if (existing == null) {
          throw ValidationFailure('ItemDefinition not found');
        }

        await _itemDefinitionsDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'item_definition',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  ItemDefinition _mapToDomain(app_db.ItemDefinition row) {
    return ItemDefinition(
      id: row.id,
      itemTypeId: row.itemTypeId,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
