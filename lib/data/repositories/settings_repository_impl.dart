import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/daos/business_settings_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class SettingsRepositoryImpl implements SettingsRepository {
  final BusinessSettingsDao _settingsDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  SettingsRepositoryImpl({
    required BusinessSettingsDao settingsDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _settingsDao = settingsDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<BusinessSettings> getSettings() async {
    try {
      final row = await _settingsDao.getSettings();
      return _mapToDomain(row);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<BusinessSettings> updateSettings(BusinessSettings settings) async {
    try {
      return await _db.transaction(() async {
        await _settingsDao.updateSettings(
          app_db.BusinessSettingsCompanion(
            id: Value(settings.id),
            businessName: Value(settings.businessName),
            address: Value(settings.address),
            phone: Value(settings.phone),
            logoReference: Value(settings.logoReference),
            invoiceFooterText: Value(settings.invoiceFooterText),
            taxEnabled: Value(settings.taxEnabled),
            taxRate: Value(settings.taxRate),
            createdAt: Value(settings.createdAt),
            updatedAt: Value(settings.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'business_settings',
          entityId: settings.id,
          operationType: 'update',
        );

        return settings;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<BusinessSettings> watchSettings() {
    try {
      return _settingsDao.watchSettings().map(_mapToDomain);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  BusinessSettings _mapToDomain(app_db.BusinessSetting row) {
    return BusinessSettings(
      id: row.id,
      businessName: row.businessName,
      address: row.address,
      phone: row.phone,
      logoReference: row.logoReference,
      invoiceFooterText: row.invoiceFooterText,
      taxEnabled: row.taxEnabled,
      taxRate: row.taxRate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
