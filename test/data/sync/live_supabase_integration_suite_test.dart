import 'step10_live_payment_integration_test.dart' as step10;
import 'step11_live_expense_integration_test.dart' as step11;
import 'step12_live_master_data_integration_test.dart' as step12;
import 'step13_live_realtime_pull_integration_test.dart' as step13;
import 'step9_live_supabase_integration_test.dart' as step9;
import 'two_device_bidirectional_sync_integration_test.dart' as c4c;

/// Deterministic sequential master suite for all live Supabase integration tests.
///
/// Ensures all live integration tests execute sequentially within a single isolate
/// to eliminate concurrency hazards and contention on shared remote Supabase resources
/// (such as global `sync_changes` sequences, shared idempotency logs, and settings).
void main() {
  step9.main();
  step10.main();
  step11.main();
  step12.main();
  step13.main();
  c4c.main();
}
