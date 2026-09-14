import '../entities/business_settings.dart';

abstract class SettingsRepository {
  Future<BusinessSettings> getSettings();
  Future<BusinessSettings> updateSettings(BusinessSettings settings);
  Stream<BusinessSettings> watchSettings();
}
