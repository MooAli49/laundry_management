# Laundry Management System (نظام إدارة المغسلة)

A production-grade, offline-first laundry management tablet application tailored for single-branch laundry operations in Egypt.

---

## Architecture & Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart) with Clean Architecture and BLoC/Cubit state management.
- **UI / UX**: Arabic-first, full RTL layout, responsive tablet UI, curated design system tokens.
- **Local Database**: [Drift](https://drift.simonbinder.eu) (SQLite) with 19 tables (schema version 6). Offline-first primary operational source of truth.
- **Remote Backend**: [Supabase](https://supabase.com) (PostgreSQL, Row-Level Security, transactional RPCs).
- **Synchronization**: Bidirectional outbox synchronization engine with single-flight push, cursor-based pull (`sync_changes`), and Supabase Realtime ephemeral wake-up signaling.

---

## Major Modules

1. **Customers**: Customer profile management, Egyptian mobile phone validation, optional customer address, customer order history.
2. **Orders**: Full aggregate order creation, editing processing orders, multi-item pricing (piece, kg, m², fixed), carpet area calculations, discounts, notes, immutable order numbers (`YY-<numeric sequence>`).
3. **Storage**: Physical item storage tracking, location compatibility by item type, bulk storage assignment, location transfers, automatic Ready transition upon complete storage.
4. **Payments & Refunds**: Immutable payment recording (Cash, InstaPay, E-Wallet), remaining balance tracking, and order-level Refund V1 for cancelled orders.
5. **Expenses**: Daily operational expense tracking, configurable master expense categories, custom-named expenses for category "أخرى".
6. **Reports**: Six-section operational financial report, sales excluding cancelled orders, net payments (payments − refunds), operating expenses, derived net profit (`Total Sales − Operating Expenses`), overdue tracking.
7. **Settings**: Business branding, service & pricing catalog, expense categories, tax settings.

---

## Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- Dart SDK

### Installation

```bash
# Clone the repository and install dependencies
flutter pub get

# Generate Drift database and JSON serialization code
dart run build_runner build --delete-conflicting-outputs
```

---

## Testing & Quality Assurance

- **Static Analysis**:
  ```bash
  flutter analyze
  ```

- **Offline / Non-Live Suite**:
  ```bash
  flutter test
  ```

- **Full Test Suite (including Live Supabase Integration Tests)**:
  ```bash
  flutter test --concurrency=1
  ```
  > [!IMPORTANT]
  > Live Supabase integration tests execute against a shared development backend instance. Running the full suite with `--concurrency=1` prevents database row contention and race conditions during live synchronization and RPC verification.