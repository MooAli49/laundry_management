/// Effective license state as evaluated by [LicenseService].
///
/// States:
/// - [active]: Remote status is 'active'. Full access granted.
/// - [gracePeriod]: Remote status is 'suspended', but fewer than 7 days have
///   elapsed since the authoritative [suspendedAt] timestamp from Supabase.
///   Normal usage is allowed. A non-dismissible warning banner is shown.
/// - [lockedOut]: Remote status is 'suspended' AND 7 or more days have elapsed
///   since [suspendedAt]. The application enters a full lock screen.
///
/// NOTE: This is practical license management, not tamper-proof DRM. A
/// motivated user with physical device access could manipulate local SQLite
/// data. The grace period is a courtesy; the lock screen is informational.
/// The owner can revoke the client's Supabase access for harder enforcement.
enum LicenseStatus {
  /// License is active. Full access permitted.
  active,

  /// License is suspended but within the 7-day grace period.
  /// Normal operation continues with a warning banner.
  gracePeriod,

  /// Grace period has expired. Application is locked to the lock screen.
  lockedOut,
}
