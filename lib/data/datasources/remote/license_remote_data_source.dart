import 'license_remote_api.dart';

/// Value object carrying the raw license data fetched from the remote API.
///
/// [status]: 'active' or 'suspended' (raw string from Supabase).
/// [suspendedAt]: Authoritative suspension start time from `license_info.suspended_at`.
///   NULL when status is 'active' or when the admin has not set a timestamp.
class LicenseRemoteData {
  final String status;
  final DateTime? suspendedAt;

  const LicenseRemoteData({required this.status, this.suspendedAt});
}

/// Contract for fetching license data from the remote backend.
abstract class LicenseRemoteDataSource {
  /// Fetches the current license state from the remote API.
  ///
  /// Throws a [DioException] or derived exception on network failure.
  /// The caller is responsible for handling connectivity errors.
  Future<LicenseRemoteData> fetchLicenseInfo();
}

/// Default implementation backed by [LicenseRemoteApi].
class LicenseRemoteDataSourceImpl implements LicenseRemoteDataSource {
  final LicenseRemoteApi _api;

  const LicenseRemoteDataSourceImpl(this._api);

  @override
  Future<LicenseRemoteData> fetchLicenseInfo() async {
    final response = await _api.getLicenseInfo();
    final json = response is Map<String, dynamic>
        ? response
        : (response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{});

    final rawStatus = json['status'];
    if (rawStatus is! String) {
      throw const FormatException(
        'Missing or invalid "status" field in license response',
      );
    }

    final status = rawStatus.trim().toLowerCase();
    if (status != 'active' && status != 'suspended') {
      throw FormatException(
        'Unknown license status "$status" in license response',
      );
    }

    final suspendedAtRaw = json['suspended_at'] as String?;
    final suspendedAt = (suspendedAtRaw != null && suspendedAtRaw.isNotEmpty)
        ? DateTime.tryParse(suspendedAtRaw)?.toLocal()
        : null;

    return LicenseRemoteData(status: status, suspendedAt: suspendedAt);
  }
}
