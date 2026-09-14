import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/carpet_size.dart';
import '../../domain/repositories/carpet_size_repository.dart';
import '../local/daos/carpet_sizes_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class CarpetSizeRepositoryImpl implements CarpetSizeRepository {
  final CarpetSizesDao _carpetSizesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  CarpetSizeRepositoryImpl({
    required CarpetSizesDao carpetSizesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _carpetSizesDao = carpetSizesDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<CarpetSize> createCarpetSize(CarpetSize carpetSize) async {
    try {
      return await _db.transaction(() async {
        await _carpetSizesDao.insertCarpetSize(
          app_db.CarpetSizesCompanion(
            id: Value(carpetSize.id),
            length: Value(carpetSize.length),
            width: Value(carpetSize.width),
            area: Value(carpetSize.area),
            isActive: Value(carpetSize.isActive),
            createdAt: Value(carpetSize.createdAt),
            updatedAt: Value(carpetSize.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'carpet_size',
          entityId: carpetSize.id,
          operationType: 'create',
        );

        return carpetSize;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<CarpetSize> updateCarpetSize(CarpetSize carpetSize) async {
    try {
      return await _db.transaction(() async {
        final existing = await _carpetSizesDao.getCarpetSizeById(carpetSize.id);
        if (existing == null) {
          throw ValidationFailure('CarpetSize not found');
        }

        await _carpetSizesDao.updateCarpetSize(
          app_db.CarpetSizesCompanion(
            id: Value(carpetSize.id),
            length: Value(carpetSize.length),
            width: Value(carpetSize.width),
            area: Value(carpetSize.area),
            isActive: Value(carpetSize.isActive),
            createdAt: Value(carpetSize.createdAt),
            updatedAt: Value(carpetSize.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'carpet_size',
          entityId: carpetSize.id,
          operationType: 'update',
        );

        return carpetSize;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<CarpetSize?> getCarpetSizeById(String id) async {
    try {
      final row = await _carpetSizesDao.getCarpetSizeById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<CarpetSize>> getActiveCarpetSizes() async {
    try {
      final rows = await _carpetSizesDao.getActiveCarpetSizes();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<CarpetSize>> getAllCarpetSizes() async {
    try {
      final rows = await _carpetSizesDao.getAllCarpetSizes();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateCarpetSize(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _carpetSizesDao.getCarpetSizeById(id);
        if (existing == null) {
          throw ValidationFailure('CarpetSize not found');
        }

        await _carpetSizesDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'carpet_size',
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
  Future<void> deactivateCarpetSize(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _carpetSizesDao.getCarpetSizeById(id);
        if (existing == null) {
          throw ValidationFailure('CarpetSize not found');
        }

        await _carpetSizesDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'carpet_size',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  CarpetSize _mapToDomain(app_db.CarpetSize row) {
    return CarpetSize(
      id: row.id,
      length: row.length,
      width: row.width,
      area: row.area,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
