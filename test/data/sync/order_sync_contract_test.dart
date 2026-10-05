import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('corrective order migration uses the client aggregate contract', () {
    final migration = File(
      'supabase/migrations/20261002000000_fix_order_sync_contract.sql',
    ).readAsStringSync();

    expect(migration, contains("'subtotal'"));
    expect(migration, contains("'total'"));
    expect(migration, contains("'expected_pickup_date'"));
    expect(migration, contains("'items', v_items"));
    expect(
      migration,
      contains("VALUES (p_op_id, 'order', p_order_id::TEXT, 'edit'"),
    );
    expect(migration, isNot(contains('total_amount')));
    expect(migration, isNot(contains("'order', jsonb_build_object")));
  });
}
