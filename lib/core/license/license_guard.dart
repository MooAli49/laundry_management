import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/license/license_service.dart';
import '../../domain/license/license_status.dart';

/// GoRouter [ChangeNotifier] bridge for license-based route gating.
///
/// Wraps [LicenseService] and notifies GoRouter's [refreshListenable]
/// mechanism whenever the effective [LicenseStatus] changes. GoRouter
/// will re-evaluate its `redirect` callback on each notification.
///
/// Usage in [AppRouter]:
///   ```dart
///   GoRouter(
///     refreshListenable: getIt<LicenseGuard>(),
///     redirect: (context, state) {
///       final status = getIt<LicenseGuard>().status;
///       ...
///     },
///   )
///   ```
class LicenseGuard extends ChangeNotifier {
  final LicenseService _service;
  StreamSubscription<LicenseStatus>? _subscription;

  LicenseStatus _status;

  LicenseGuard(LicenseService service)
    : _service = service,
      _status = service.currentStatus {
    _subscription = service.statusStream.listen((status) {
      if (_status != status) {
        _status = status;
        notifyListeners();
      }
    });
  }

  /// Current effective license status. Read by GoRouter's redirect callback.
  LicenseStatus get status => _status;

  /// The authoritative suspension timestamp for grace-period calculations
  /// (e.g., how many days remain for the warning banner).
  DateTime? get suspendedAt => _service.suspendedAt;

  /// Days remaining in the grace period (0 if not in [LicenseStatus.gracePeriod]).
  int get daysRemainingInGrace {
    if (_status != LicenseStatus.gracePeriod) return 0;
    final suspendedAtValue = _service.suspendedAt;
    final graceDays = kLicenseGracePeriod.inDays;
    if (suspendedAtValue == null) return graceDays; // No timestamp → show max
    final elapsed = DateTime.now().difference(suspendedAtValue).inDays;
    return (graceDays - elapsed).clamp(0, graceDays);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
