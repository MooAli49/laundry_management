# Environment Architecture & Isolation Model

This document establishes the official multi-environment architecture, isolation policies, and production deployment specifications for the Laundry Management System.

---

## 1. Environments Overview

| Environment | Target Supabase Project | Project Ref | Region | Primary Purpose | Database Content | Client Configuration |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Development** | `laundry_management_system` | `dyhfgnbhijukbdptreto` | West EU (Ireland) | Local feature development, schema migrations, and rapid iteration | Disposable test data + canonical baseline | Default debug fallback (`SupabaseConfig.defaultDevUrlRoot`) |
| **Integration Testing** | `laundry_management_system` | `dyhfgnbhijukbdptreto` | West EU (Ireland) | Automated live integration test suites (`test/data/sync/*`) | Continuous test artifacts, automated test orders, customers, expenses | CI/CD and test harnesses targeting development backend |
| **Production** | `Laundry Management PROD` | `rvrskluqfbrkvvlxtxfp` | West EU (Ireland) | Live production business operations | Pristine canonical baseline seed only (0 transactional records) | Mandatory `--dart-define` injection at build time |

---

## 2. Environment Isolation Rules

### 2.1 Complete Infrastructure Separation
- **No Shared Databases**: Production and Development/Integration Testing **must never share the same database or Supabase project**.
- **No Test Execution on Production**: Automated integration tests (`live_supabase_integration_suite_test.dart`, etc.) must **NEVER** run against the Production Supabase project. They generate hundreds of mutations, customer records, and orders that would pollute production sync cursors and business logs.
- **Strict Development Script Isolation**: The development reset script (`scripts/dev_supabase_safe_reset.sql`) is guarded with session tokens and project ref assertions (`app.project_ref = 'dyhfgnbhijukbdptreto'`) and is strictly prohibited from running against Production.

### 2.2 Credentials Separation
- **Public Anonymous Key (`SUPABASE_ANON_KEY`)**:
  - Development and Production use completely distinct public anonymous keys.
  - Production credentials must be supplied at compile time via:
    ```bash
    --dart-define=SUPABASE_URL_ROOT=https://rvrskluqfbrkvvlxtxfp.supabase.co
    --dart-define=SUPABASE_ANON_KEY=<production-anon-key>
    ```
  - In release builds, `SupabaseConfig.resolve()` strictly prohibits silent fallback to development credentials and throws a `StateError` if release defines are omitted.
- **Service-Role Key (`SUPABASE_SERVICE_ROLE_KEY`)**:
  - `SUPABASE_SERVICE_ROLE_KEY` is maintained **server-side exclusively** within the Supabase Edge Function environment for each project.
  - The service-role key is **NEVER** embedded into the Flutter client, checked into source control, or exposed in CI logs.
  - Client devices communicate with the backend exclusively via the public HTTP Edge Function (`/functions/v1/api/*`), which holds the trusted service-role client.

---

## 3. Production Environment Specifications

### 3.1 Project Details
- **Project Name**: `Laundry Management PROD`
- **Project Ref**: `rvrskluqfbrkvvlxtxfp`
- **Region**: `eu-west-1` (West EU - Ireland)
- **URL Root**: `https://rvrskluqfbrkvvlxtxfp.supabase.co`
- **Edge Function API URL**: `https://rvrskluqfbrkvvlxtxfp.supabase.co/functions/v1/api`

### 3.2 Applied Migrations (14 Total)
The production database was provisioned using `npx supabase db push` across all 14 repository migrations in chronological order:
1. `20260916000000_step8_sync_schema.sql`
2. `20260916000001_sync_rpc_functions.sql`
3. `20260916000002_payments_schema.sql`
4. `20260916000003_expenses_schema.sql`
5. `20260916000004_master_data_schema.sql`
6. `20260917000000_remote_sync_foundation.sql`
7. `20260918000000_realtime_sync_changes.sql`
8. `20260919000000_enforce_master_foreign_keys.sql`
9. `20260923000000_sync_update_order_aggregate.sql`
10. `20260923000001_restrict_edit_order_to_processing.sql`
11. `20260923000002_allow_completed_to_processing_correction.sql`
12. `20260924000000_refunds_schema.sql`
13. `20260925000000_customer_address.sql`
14. `20260926000000_security_hardening.sql`

### 3.3 Database Security & Posture Verification
- **Advisors Report**: `npx supabase db advisors --linked` reports **0 issues found** (0 warnings, 0 errors).
- **Public Tables**: Exactly 19 tables in `public` schema.
- **Row Level Security (RLS)**: Enabled with default-deny on all 19 public tables (`policy_count = 0`).
- **Direct Table DML Permissions**: Direct `INSERT`, `UPDATE`, `DELETE`, and `TRUNCATE` revoked from `PUBLIC`, `anon`, and `authenticated` roles.
- **Stored Functions (26 Total)**:
  - All 26 functions configured as `SECURITY DEFINER`.
  - All 26 functions have `SET search_path = public, pg_temp` explicitly pinned.
  - Direct execution revoked from `PUBLIC`, `anon`, and `authenticated`; granted strictly to `service_role` and `postgres`.
- **Realtime Publication**: `sync_changes` table added to `supabase_realtime` publication with replica identity `FULL`.

### 3.4 Seed Baseline (Canonical Master Data Only)
The production environment was seeded using [`scripts/prod_supabase_seed_canonical_baseline.sql`](file:///d:/projects/laundry_management/scripts/prod_supabase_seed_canonical_baseline.sql), establishing the 35 canonical baseline sync changes:
- `sync_changes`: Exactly 35 records (sequences 1..35, contiguous with no gaps).
- `business_settings`: 1 singleton record (`tax_enabled = false`, `tax_rate = 0.0`, `server_version = 1`).
- `item_types`: 4 active records (`ملابس`, `بطاطين`, `سجاد`, `أغطية`).
- `expense_categories`: 7 active records (`إيجار`, `كهرباء ومياه`, `منظفات ومواد غسيل`, `صيانة معدات`, `أجور ومكافآت`, `نثريات وضيافة`, `أخرى`).
- `services`: 5 active records (`غسيل ومكوى`, `مكوى فقط`, `غسيل سريع`, `دراي كلين`, `غسيل بطاطين/سجاد`).
- `carpet_sizes`: 3 active records (`2.0x3.0`, `1.5x2.0`, `1.0x4.0`).
- `storage_locations`: 5 active records (`رف أ-1`, `رف أ-2`, `رف ب-1`, `قسم السجاد 1`, `قسم البطاطين 1`).
- `item_definitions`: 10 active records (`قميص`, `بنطلون`, `بدلة`, `بطانية مفرد`, `بطانية دبل`, `سجادة صوف`, `مشاية`, `غطاء لحاف`, `كوفرتة`, `سجادة حرير`).
- **Transactional Records**: Exactly 0 across all transactional tables:
  - `customers = 0`
  - `orders = 0`
  - `payments = 0`
  - `refunds = 0`
  - `expenses = 0`
  - `storage_records = 0`
  - `sync_idempotency_log = 0`

### 3.5 Edge Functions
- **Function Name**: `api`
- **Status**: `ACTIVE` (Version 1)
- **JWT Verification**: Disabled (`verify_jwt: false`), with application-level security and service-role database access handled inside the Edge Function.
- **Endpoints Available**:
  - `GET /sync/changes?after={seq}&limit={n}`
  - `POST /sync/batch`
  - `POST /orders`, `PATCH /orders/{id}`, `POST /orders/{id}/cancel`
  - `POST /customers`, `PATCH /customers/{id}`, `DELETE /customers/{id}`
  - `POST /payments`, `POST /refunds`
  - `POST /expenses`, `DELETE /expenses/{id}`
  - `POST /storage/records`, `DELETE /storage/records/{id}`
  - `PATCH /settings`

---

## 4. Flutter Production Release Build Guide

### 4.1 Application Package Identity
- **Android Package / Application ID**: `com.mooali.laundry_management`
- **Namespace**: `com.mooali.laundry_management`
- **Target SDK**: `36` (Android 16)
- **Min SDK**: `24` (Android 7.0)

### 4.2 Building Production Release APK
Execute from workspace root:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL_ROOT=https://rvrskluqfbrkvvlxtxfp.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<PRODUCTION_ANON_KEY>
```

### 4.3 Building Production Release App Bundle (AAB)
Execute for Google Play Store upload:
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL_ROOT=https://rvrskluqfbrkvvlxtxfp.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<PRODUCTION_ANON_KEY>
```
