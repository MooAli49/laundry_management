import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/repositories/settings_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/settings_cubit.dart';

class FakeSettingsRepository implements SettingsRepository {
  bool shouldThrow = false;
  BusinessSettings settings = BusinessSettings(
    id: 'settings-1',
    businessName: 'مغسلة التجربة',
    phone: '01000000000',
    address: 'العنوان التجريبي',
    taxEnabled: false,
    taxRate: 0.0,
    invoiceFooterText: 'شكراً لتعاملكم',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final _controller = StreamController<BusinessSettings>.broadcast();

  @override
  Future<BusinessSettings> getSettings() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return settings;
  }

  @override
  Future<BusinessSettings> updateSettings(BusinessSettings newSettings) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    settings = newSettings;
    _controller.add(newSettings);
    return settings;
  }

  @override
  Stream<BusinessSettings> watchSettings() {
    return _controller.stream;
  }
}

void main() {
  late FakeSettingsRepository repository;
  late SettingsCubit cubit;

  setUp(() {
    repository = FakeSettingsRepository();
    cubit = SettingsCubit(settingsRepository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('SettingsCubit Tests', () {
    test('initial state has default values', () {
      expect(cubit.state.selectedTabIndex, 0);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.settings, isNull);
    });

    test('selectTab updates selectedTabIndex and clears messages', () {
      cubit.selectTab(2);
      expect(cubit.state.selectedTabIndex, 2);
    });

    test('loadSettings successfully loads settings', () async {
      await cubit.loadSettings();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.settings?.businessName, 'مغسلة التجربة');
      expect(cubit.state.errorMessage, isNull);
    });

    test('loadSettings sets errorMessage on failure', () async {
      repository.shouldThrow = true;
      await cubit.loadSettings();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, 'DB error');
    });

    test(
      'updateBusinessInfo successfully updates business information',
      () async {
        await cubit.loadSettings();

        final result = await cubit.updateBusinessInfo(
          businessName: 'مغسلة الأمل الحديثة',
          phone: '01111111111',
          address: 'شارع التحرير',
          invoiceFooterText: 'أهلاً بكم دائماً',
        );

        expect(result, isTrue);
        expect(cubit.state.isSaving, isFalse);
        expect(cubit.state.settings?.businessName, 'مغسلة الأمل الحديثة');
        expect(cubit.state.settings?.phone, '01111111111');
        expect(cubit.state.settings?.address, 'شارع التحرير');
        expect(cubit.state.settings?.invoiceFooterText, 'أهلاً بكم دائماً');
        expect(
          cubit.state.saveSuccessMessage,
          AppStrings.saveBusinessSettingsSuccess,
        );
      },
    );

    test('updateBusinessInfo rejects empty or whitespace-only name', () async {
      await cubit.loadSettings();

      final result1 = await cubit.updateBusinessInfo(businessName: '');
      expect(result1, isFalse);
      expect(cubit.state.errorMessage, AppStrings.businessNameRequired);

      final result2 = await cubit.updateBusinessInfo(businessName: '   ');
      expect(result2, isFalse);
      expect(cubit.state.errorMessage, AppStrings.businessNameRequired);
    });
  });
}
