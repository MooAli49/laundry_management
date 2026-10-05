import 'dart:async';
import 'dart:developer' as developer;

import '../../core/network/network_info.dart';
import '../../data/datasources/remote/license_remote_data_source.dart';
import '../../data/local/daos/license_cache_dao.dart';
import '../../domain/license/license_status.dart';

/// Grace period duration — 7 days from the authoritative [suspendedAt] timestamp.
const Duration kLicenseGracePeriod = Duration(days: 7);

/// Maximum time between remote license checks while the app is running.
const Duration _kCheckInterval = Duration(hours: 24);

/// Application-layer service that evaluates and broadcasts the effective
/// [LicenseStatus] of this installation.
///
/// Design decisions:
///
/// 1. AUTHORITATIVE TIMESTAMP: The grace-period clock is anchored to
///    `license_info.suspended_at` from Supabase — not to the moment the device
///    first discovers the suspension. This prevents an offline device from
///    receiving a fresh 7-day window simply because it came online late.
///    When the admin re-suspends after a reactivation, the newer
///    `suspended_at` takes precedence and resets the grace window.
///
/// 2. OFFLINE / NO CACHE: On first launch with no connectivity and no cached
///    license, the service fails open (returns [LicenseStatus.active]). This is
///    the simplest behaviour compatible with the offline-first architecture and
///    avoids blocking a brand-new installation from operating. Once connectivity
///    is restored the 24-hour check will run and cache the real state.
///
/// 3. THROTTLING: Remote checks are limited to once every 24 hours to avoid
///    making normal business operations network-dependent. The throttle is
///    respected even when connectivity is restored, unless the cache is absent.
///
/// 4. TAMPER DISCLAIMER: This is practical license control, not tamper-proof
///    DRM. A user with physical device access could manipulate the local SQLite
///    cache. The owner can revoke Supabase access for harder enforcement.
class LicenseService {
  final LicenseRemoteDataSource _remoteDataSource;
  final LicenseCacheDao _cacheDao;
  final NetworkInfo _networkInfo;
  final DateTime Function() _clock;
  final Timer Function(Duration duration, void Function() callback)
  _timerFactory;

  LicenseStatus _currentStatus = LicenseStatus.active;
  DateTime? _suspendedAt;
  Timer? _gracePeriodTimer;

  final StreamController<LicenseStatus> _statusController =
      StreamController<LicenseStatus>.broadcast();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isDisposed = false;

  LicenseService({
    required LicenseRemoteDataSource remoteDataSource,
    required LicenseCacheDao cacheDao,
    required NetworkInfo networkInfo,
    DateTime Function()? clock,
    Timer Function(Duration duration, void Function() callback)? timerFactory,
  }) : _remoteDataSource = remoteDataSource,
       _cacheDao = cacheDao,
       _networkInfo = networkInfo,
       _clock = clock ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new;

  /// The latest evaluated license status. Synchronous after [initialize].
  LicenseStatus get currentStatus => _currentStatus;

  /// The authoritative suspension timestamp (from Supabase), used by the UI
  /// to calculate days remaining in the grace period.
  DateTime? get suspendedAt => _suspendedAt;

  /// Stream of status changes. GoRouter's [LicenseGuard] subscribes to this.
  Stream<LicenseStatus> get statusStream => _statusController.stream;

  /// Performs the initial license check at application startup.
  ///
  /// Must be awaited in [main()] before [runApp()] so that the router has
  /// an accurate initial status when the first frame is rendered.
  Future<void> initialize() async {
    await _refreshStatus(force: true);

    // Subscribe to connectivity recovery — re-check when coming back online,
    // still honouring the 24-hour throttle so the app does not spin on every
    // reconnect.
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (_isDisposed) return;
        if (isConnected) {
          // Fire-and-forget: errors are swallowed to avoid crashing on reconnect.
          _refreshStatus().catchError((_) => null);
        }
      },
      onError: (_) {
        // Connectivity stream errors are safely ignored.
      },
    );
  }

  /// Called by the [AppLifecycleListener] on app resume.
  ///
  /// Performs a remote re-check if more than 24 hours have passed since the
  /// last successful check, or if there is no cached data at all.
  Future<void> checkIfDue() async {
    if (_isDisposed) return;
    await _refreshStatus();
  }

  /// Core refresh logic.
  ///
  /// [force] bypasses the 24-hour throttle. Used at startup.
  Future<void> _refreshStatus({bool force = false}) async {
    if (_isDisposed) return;

    try {
      final cached = await _cacheDao.getCached();

      // 24-hour throttle: skip remote fetch unless forced or cache is stale.
      final needsRemoteFetch = force || _isCheckDue(cached?.lastCheckedAt);

      if (needsRemoteFetch) {
        final isOnline = await _networkInfo.isConnected;
        if (isOnline) {
          try {
            final remote = await _remoteDataSource.fetchLicenseInfo();
            final effectiveSuspendedAt = _resolveEffectiveSuspendedAt(
              remote,
              cached?.suspendedAt,
            );

            await _cacheDao.saveCache(
              remoteStatus: remote.status,
              suspendedAt: effectiveSuspendedAt,
              lastCheckedAt: _clock(),
            );

            _emitStatus(
              _computeStatus(remote.status, effectiveSuspendedAt),
              effectiveSuspendedAt,
            );
            return;
          } catch (e, stack) {
            // Remote fetch failed; fall through to cached value.
            _log('License remote check failed, using cache: $e', e, stack);
          }
        }
      }

      // Use local cache.
      if (cached == null) {
        // No cache and not online (or remote failed on first launch).
        // Fail open — see class-level design note (2).
        _emitStatus(LicenseStatus.active, null);
        return;
      }

      _emitStatus(
        _computeStatus(cached.remoteStatus, cached.suspendedAt),
        cached.suspendedAt,
      );
    } catch (e, stack) {
      // Defensive: any unexpected error keeps the last known status.
      _log('Unexpected error in license refresh: $e', e, stack);
    }
  }

  /// Determines whether a remote fetch is overdue.
  bool _isCheckDue(DateTime? lastCheckedAt) {
    if (lastCheckedAt == null) return true;
    return _clock().difference(lastCheckedAt) >= _kCheckInterval;
  }

  /// Resolves which `suspended_at` timestamp to store locally.
  ///
  /// - If remote returns 'active': always null (clears any prior suspension).
  /// - If remote returns 'suspended' with a timestamp:
  ///     - Use the remote value if it is newer than the cached value
  ///       (admin re-suspended with a fresh `suspended_at` → reset grace window).
  ///     - Otherwise keep the existing cached value
  ///       (stable grace window for an ongoing suspension).
  /// - If remote returns 'suspended' with no timestamp:
  ///     - Fall back to existing cached value.
  DateTime? _resolveEffectiveSuspendedAt(
    LicenseRemoteData remote,
    DateTime? cachedSuspendedAt,
  ) {
    if (remote.status != 'suspended') return null;

    final remoteSuspendedAt = remote.suspendedAt;

    if (remoteSuspendedAt != null && cachedSuspendedAt != null) {
      // Use whichever is more recent (handles re-suspension after reactivation).
      return remoteSuspendedAt.isAfter(cachedSuspendedAt)
          ? remoteSuspendedAt
          : cachedSuspendedAt;
    }

    return remoteSuspendedAt ?? cachedSuspendedAt;
  }

  /// Converts raw status string + suspension timestamp into [LicenseStatus].
  LicenseStatus _computeStatus(String remoteStatus, DateTime? suspendedAt) {
    if (remoteStatus != 'suspended') {
      return LicenseStatus.active;
    }

    if (suspendedAt == null) {
      // Admin suspended but did not set a timestamp — treat as grace period
      // with no defined expiry until the next successful remote check provides
      // a proper suspended_at.
      return LicenseStatus.gracePeriod;
    }

    final elapsed = _clock().difference(suspendedAt);
    if (elapsed >= kLicenseGracePeriod) {
      return LicenseStatus.lockedOut;
    }
    return LicenseStatus.gracePeriod;
  }

  void _cancelGraceTimer() {
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = null;
  }

  void _onGracePeriodTimerExpired() {
    if (_isDisposed) return;
    _gracePeriodTimer = null;

    final suspendedAtValue = _suspendedAt;
    if (suspendedAtValue == null) return;

    final elapsed = _clock().difference(suspendedAtValue);
    if (elapsed >= kLicenseGracePeriod) {
      _emitStatus(LicenseStatus.lockedOut, suspendedAtValue);
    }
  }

  void _emitStatus(LicenseStatus status, DateTime? suspendedAt) {
    _currentStatus = status;
    _suspendedAt = suspendedAt;

    _cancelGraceTimer();

    if (status == LicenseStatus.gracePeriod && suspendedAt != null) {
      final expiry = suspendedAt.add(kLicenseGracePeriod);
      final remaining = expiry.difference(_clock());
      if (remaining.isNegative || remaining == Duration.zero) {
        _currentStatus = LicenseStatus.lockedOut;
        status = LicenseStatus.lockedOut;
      } else {
        _gracePeriodTimer = _timerFactory(
          remaining,
          _onGracePeriodTimerExpired,
        );
      }
    }

    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _log(String message, [Object? error, StackTrace? stack]) {
    developer.log(
      message,
      name: 'LicenseService',
      error: error,
      stackTrace: stack,
    );
  }

  /// Releases resources. Called by GetIt dispose callback.
  void dispose() {
    _isDisposed = true;
    _cancelGraceTimer();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}
