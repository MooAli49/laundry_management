import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/license_remote_data_source.dart';

class _FakeLicenseRemoteApi implements LicenseRemoteApi {
  dynamic response;
  bool shouldThrow = false;

  @override
  Future<dynamic> getLicenseInfo() async {
    if (shouldThrow) throw Exception('Network error');
    return response;
  }
}

void main() {
  late _FakeLicenseRemoteApi fakeApi;
  late LicenseRemoteDataSourceImpl dataSource;

  setUp(() {
    fakeApi = _FakeLicenseRemoteApi();
    dataSource = LicenseRemoteDataSourceImpl(fakeApi);
  });

  group('LicenseRemoteDataSourceImpl Validation', () {
    test('parses active status correctly with null suspended_at', () async {
      fakeApi.response = {
        'status': 'active',
        'suspended_at': null,
        'updated_at': '2026-09-24T12:00:00Z',
      };

      final result = await dataSource.fetchLicenseInfo();
      expect(result.status, equals('active'));
      expect(result.suspendedAt, isNull);
    });

    test('parses suspended status correctly with ISO timestamp', () async {
      fakeApi.response = {
        'status': 'suspended',
        'suspended_at': '2026-09-20T10:30:00Z',
        'updated_at': '2026-09-20T10:30:00Z',
      };

      final result = await dataSource.fetchLicenseInfo();
      expect(result.status, equals('suspended'));
      expect(result.suspendedAt, isNotNull);
      expect(
        result.suspendedAt!.toUtc(),
        equals(DateTime.parse('2026-09-20T10:30:00Z')),
      );
    });

    test('throws FormatException when status is missing', () async {
      fakeApi.response = {
        'suspended_at': null,
        'updated_at': '2026-09-24T12:00:00Z',
      };

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when status is null', () async {
      fakeApi.response = {'status': null, 'suspended_at': null};

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when status is not a string', () async {
      fakeApi.response = {'status': 123};

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when status is unknown string', () async {
      fakeApi.response = {'status': 'unknown_status'};

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when status is expired or pending', () async {
      fakeApi.response = {'status': 'expired'};

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when response is not a map', () async {
      fakeApi.response = 'not a map';

      expect(
        () => dataSource.fetchLicenseInfo(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
