# Development Supabase Operational Runbook

## 1. Purpose & Scope

This runbook defines the approved operational procedures for resetting and restoring the **development** Supabase environment to the pristine Phase 3A canonical baseline.

> [!CAUTION]
> ### STRICT SAFETY BOUNDARY: DISPOSABLE DEVELOPMENT ENVIRONMENT ONLY
> - These operational scripts are designed **EXCLUSIVELY** for the development Supabase project (`dyhfgnbhijukbdptreto`).
> - These scripts **MUST NEVER BE RUN AGAINST PRODUCTION**.
> - The development database used during V1 development and integration testing is intentionally disposable.
> - Never execute arbitrary `DELETE`, `TRUNCATE`, or `DROP` statements outside these reviewed and guarded scripts.

---

## 2. Approved Operational Scripts

The project maintains two reviewed, guarded SQL scripts under [`scripts/`](file:///d:/projects/laundry_management/scripts):

| Script | Purpose | Transactionality | Guard Requirements |
| :--- | :--- | :--- | :--- |
| [`scripts/dev_supabase_safe_reset.sql`](file:///d:/projects/laundry_management/scripts/dev_supabase_safe_reset.sql) | Atomic reverse-dependency purge of transactional & test data | Single `BEGIN ... COMMIT` | Asserted Project Ref, Environment = `'development'`, Confirmation Token |
| [`scripts/dev_supabase_seed_canonical_baseline.sql`](file:///d:/projects/laundry_management/scripts/dev_supabase_seed_canonical_baseline.sql) | Atomic seeding of the canonical 35-change master baseline | Single `BEGIN ... COMMIT` | Asserted Project Ref, Environment = `'development'`, Confirmation Token |

---

## 3. Workflow A: Safe Database Reset

### 3.1 Script: `scripts/dev_supabase_safe_reset.sql`

When integration tests or verification runs introduce test rows or duplicate data that need to be cleared, run the guarded safe reset script.

### 3.2 What It Does
1. **Verifies Environment Guards**:
   - `app.project_ref = 'dyhfgnbhijukbdptreto'`
   - `app.environment = 'development'`
   - `app.confirm_safe_reset = 'CONFIRMED_SAFE_RESET_2026_DYHFGNBHIJUKBDPTRETO'`
   - Checks that `current_database()` does not contain production signatures (`prod`, `production`, `live`).
2. **Reverse-Dependency Deletion**:
   - Deletes in strict foreign key reverse dependency order:
     1. Transactional data: `sync_idempotency_log`, `order_item_carpets`, `order_items`, `orders`, `payments`, `storage_records`, `expenses`, `customers`.
     2. Junction tables: `service_item_types`, `storage_location_item_types`.
     3. Master catalog entities: `item_definitions`, `storage_locations`, `carpet_sizes`, `services`, `expense_categories`, `item_types`.
     4. Synchronisation change log: `sync_changes`.
3. **Preserves Business Settings Singleton**:
   - Resets the `business_settings` singleton (`id = '00000000-0000-0000-0000-000000000001'`) to its canonical baseline state (`business_name = ''`, `tax_enabled = false`, `tax_rate = 0.0`, `server_version = 1`).
4. **Resets Sequence**:
   - Resets `sync_changes_sequence_seq` back to `1` (`is_called = false`), ensuring the next insert receives sequence `1`.
5. **Post-Reset Assertions**:
   - Asserts that all transactional and master tables are at count 0, `business_settings` is exactly 1, and `sync_changes` is 0. If any assertion fails, the entire transaction rolls back (`ROLLBACK`).

### 3.3 Execution
Execute atomically via Supabase SQL Editor or migration runner:
```sql
-- scripts/dev_supabase_safe_reset.sql
BEGIN;
SET LOCAL app.project_ref = 'dyhfgnbhijukbdptreto';
SET LOCAL app.environment = 'development';
SET LOCAL app.confirm_safe_reset = 'CONFIRMED_SAFE_RESET_2026_DYHFGNBHIJUKBDPTRETO';

-- ... (remainder of script executes within transaction)
COMMIT;
```

---

## 4. Workflow B: Canonical Baseline Seed

### 4.1 Script: `scripts/dev_supabase_seed_canonical_baseline.sql`

Must be executed **immediately after** a successful safe reset.

### 4.2 What It Does
1. **Verifies Environment Guards**:
   - `app.project_ref = 'dyhfgnbhijukbdptreto'`
   - `app.environment = 'development'`
   - `app.confirm_canonical_seed = 'CONFIRMED_CANONICAL_SEED_2026_DYHFGNBHIJUKBDPTRETO'`
   - Asserts that `sync_changes` is empty and next sequence is `1`.
2. **Deterministic Timestamp Capture**:
   - Uses a single transaction timestamp (`current_setting('app.seed_ts')`) for both the relational records and their embedded payload snapshots, guaranteeing exact matching between relational rows and changelog entries.
3. **Seeds Relational Master Data**:
   - `business_settings`: 1 singleton row
   - `item_types`: 4 canonical categories (`ملابس`, `بطاطين`, `سجاد`, `أغطية`)
   - `expense_categories`: 7 canonical categories (`كهرباء`, `مياه`, `منظفات`, `صيانة`, `مستلزمات`, `نقل`, `أخرى`)
   - `services`: 5 canonical services (`غسيل ومكوى`, `دراي كلين`, `غسيل سجاد`, `تنظيف بطاطين`, `غسيل أغطية`)
   - `service_item_types`: 5 canonical junction mappings
   - `carpet_sizes`: 3 standard dimensions (`2.0x3.0`, `1.5x2.0`, `1.0x4.0`)
   - `storage_locations`: 5 locations (`رف أ-1`, `رف أ-2`, `رف ب-1`, `قسم السجاد 1`, `قسم البطاطين 1`)
   - `storage_location_item_types`: 9 location-to-type capability links
   - `item_definitions`: 10 preconfigured item definitions
4. **Appends Exactly 35 Canonical Sync Changes (Sequences 1..35)**:
   - Sequence 1: `business_settings`
   - Sequences 2..5: `item_type` (4 changes)
   - Sequences 6..12: `expense_category` (7 changes)
   - Sequences 13..17: `service` (5 changes, includes `supported_item_type_ids`)
   - Sequences 18..20: `carpet_size` (3 changes)
   - Sequences 21..25: `storage_location` (5 changes, includes `supported_item_type_ids`)
   - Sequences 26..35: `item_definition` (10 changes)
5. **Post-Seed Assertions**:
   - Verifies that `min(sequence) = 1`, `max(sequence) = 35`, count is exactly 35 with zero sequence gaps.

---

## 5. Post-Restoration Verification Checklist

Following safe reset and canonical seeding, verify the following:

- [ ] `SELECT COUNT(*) FROM sync_changes;` equals `35`
- [ ] `SELECT MIN(sequence), MAX(sequence) FROM sync_changes;` returns `1, 35`
- [ ] `SELECT public.get_sync_changes(0, 100);` returns all 35 records with `has_more = false` and `latest_sequence = 35`
- [ ] Transactional tables (`orders`, `customers`, `payments`, `expenses`, `storage_records`, `sync_idempotency_log`) are completely empty (0 rows)
- [ ] Fresh client install bootstraps from cursor 0 cleanly to cursor 35 without errors
