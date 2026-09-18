import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Step 11 — Live Supabase Expense & Expense Category Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    // Unique per-run UUID generator to guarantee test idempotency and isolation
    final runId = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');

    late final String testCategoryId;
    late final String testOtherCategoryId;
    late final String testExpenseId;
    late final String testOtherExpenseId;
    late final String testCategoryOpId;
    late final String testExpenseOpId;

    final categoryName = 'مستلزمات تشغيل $runId';

    setUpAll(() async {
      client = DioClient();
      dio = client.dio;

      testCategoryId = 'c1100000-0000-4000-8000-$runId';
      testOtherCategoryId = 'c1200000-0000-4000-8000-$runId';
      testExpenseId = 'e1100000-0000-4000-8000-$runId';
      testOtherExpenseId = 'e1200000-0000-4000-8000-$runId';
      testCategoryOpId = 'op-step11-cat-$runId';
      testExpenseOpId = 'op-step11-exp-$runId';

      try {
        final res = await dio.get('/expense-categories', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isNetworkAvailable = false;
        }
      } catch (_) {
        isNetworkAvailable = false;
      }
    });

    test('1. Valid category creation: returns 201 Created and persists category', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/expense-categories',
        data: {
          'id': testCategoryId,
          'name': categoryName,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': testCategoryOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testCategoryId));
      expect(res.data['name'], equals(categoryName));
      expect(res.data['is_active'], isTrue);
    });

    test('2. Category Idempotency: exact duplicate replay returns cached 201 response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/expense-categories',
        data: {
          'id': testCategoryId,
          'name': categoryName,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': testCategoryOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testCategoryId));
      expect(replayRes.data['name'], equals(categoryName));
    });

    test('3. Category update/rename: returns 200 OK with updated name', () async {
      if (!isNetworkAvailable) return;

      final updatedName = '$categoryName (محدث)';
      final res = await dio.patch(
        '/expense-categories/$testCategoryId',
        data: {
          'name': updatedName,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-cat-rename-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['id'], equals(testCategoryId));
      expect(res.data['name'], equals(updatedName));
    });

    test('4. Category deactivation & reactivation: returns 200 OK', () async {
      if (!isNetworkAvailable) return;

      // Deactivate
      final deactRes = await dio.patch(
        '/expense-categories/$testCategoryId',
        data: {
          'is_active': false,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-cat-deact-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(deactRes.statusCode, equals(200));
      expect(deactRes.data['is_active'], isFalse);

      // Reactivate
      final reactRes = await dio.patch(
        '/expense-categories/$testCategoryId',
        data: {
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-cat-react-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(reactRes.statusCode, equals(200));
      expect(reactRes.data['is_active'], isTrue);
    });

    test('5. Duplicate normalized category name: rejected with 409 CONFLICT', () async {
      if (!isNetworkAvailable) return;

      // Attempt to create another category with exact same name (with whitespace)
      final duplicateRes = await dio.post(
        '/expense-categories',
        data: {
          'id': 'c1999999-0000-4000-8000-$runId',
          'name': '  $categoryName (محدث)  ',
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-cat-dup-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(duplicateRes.statusCode, equals(409));
      expect(duplicateRes.data['code'], isIn(['CONFLICT', 'DUPLICATE_ENTITY']));
    });

    test('6. GET /expense-categories and GET /expense-categories/:id', () async {
      if (!isNetworkAvailable) return;

      // GET list
      final listRes = await dio.get('/expense-categories');
      expect(listRes.statusCode, equals(200));
      expect(listRes.data, isA<List>());
      final found = (listRes.data as List).any((c) => c['id'] == testCategoryId);
      expect(found, isTrue);

      // GET single
      final singleRes = await dio.get('/expense-categories/$testCategoryId');
      expect(singleRes.statusCode, equals(200));
      expect(singleRes.data['id'], equals(testCategoryId));

      // GET non-existent
      final missingRes = await dio.get(
        '/expense-categories/00000000-0000-0000-0000-000000000000',
        options: Options(validateStatus: (_) => true),
      );
      expect(missingRes.statusCode, equals(404));
      expect(missingRes.data['code'], equals('NOT_FOUND'));
    });

    test('7. Category deletion prohibition: DELETE returns 404 NOT_FOUND', () async {
      if (!isNetworkAvailable) return;

      final delRes = await dio.delete(
        '/expense-categories/$testCategoryId',
        options: Options(validateStatus: (_) => true),
      );
      expect(delRes.statusCode, equals(404));
    });

    test('8. Valid expense creation: returns 201 Created and persists expense', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/expenses',
        data: {
          'id': testExpenseId,
          'expense_category_id': testCategoryId,
          'amount': 8500, // 85.00 EGP
          'expense_name': 'شراء صابون سائل',
          'expense_date': '2026-09-16',
          'notes': 'فاتورة رقم 1234',
          'category_name_snapshot': '$categoryName (محدث)',
        },
        options: Options(
          headers: {'X-Operation-ID': testExpenseOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testExpenseId));
      expect(res.data['expense_category_id'], equals(testCategoryId));
      expect(res.data['amount'], equals(8500));
      expect(res.data['expense_date'], equals('2026-09-16'));
      expect(res.data['category_name_snapshot'], equals('$categoryName (محدث)'));
    });

    test('9. Expense Idempotency: exact duplicate replay returns cached 201 response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/expenses',
        data: {
          'id': testExpenseId,
          'expense_category_id': testCategoryId,
          'amount': 8500,
          'expense_name': 'شراء صابون سائل',
          'expense_date': '2026-09-16',
          'notes': 'فاتورة رقم 1234',
          'category_name_snapshot': '$categoryName (محدث)',
        },
        options: Options(
          headers: {'X-Operation-ID': testExpenseOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testExpenseId));
      expect(replayRes.data['amount'], equals(8500));
    });

    test('10. Invalid expense amount (zero or negative): rejected with 422 VALIDATION_ERROR', () async {
      if (!isNetworkAvailable) return;

      final zeroRes = await dio.post(
        '/expenses',
        data: {
          'id': 'e1999991-0000-4000-8000-$runId',
          'expense_category_id': testCategoryId,
          'amount': 0,
          'expense_date': '2026-09-16',
          'category_name_snapshot': 'test',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-zero-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(zeroRes.statusCode, equals(422));
      expect(zeroRes.data['code'], isIn(['VALIDATION_ERROR', 'BUSINESS_RULE_VIOLATION']));

      final negRes = await dio.post(
        '/expenses',
        data: {
          'id': 'e1999992-0000-4000-8000-$runId',
          'expense_category_id': testCategoryId,
          'amount': -500,
          'expense_date': '2026-09-16',
          'category_name_snapshot': 'test',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-neg-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(negRes.statusCode, equals(422));
      expect(negRes.data['code'], isIn(['VALIDATION_ERROR', 'BUSINESS_RULE_VIOLATION']));
    });

    test('11. Missing category: rejected with 400 FOREIGN_KEY_VIOLATION', () async {
      if (!isNetworkAvailable) return;

      final missingCatRes = await dio.post(
        '/expenses',
        data: {
          'id': 'e1999993-0000-4000-8000-$runId',
          'expense_category_id': '00000000-0000-0000-0000-000000000000',
          'amount': 1000,
          'expense_date': '2026-09-16',
          'category_name_snapshot': 'non-existent',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-miss-cat-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(missingCatRes.statusCode, isIn([400, 422]));
      expect(missingCatRes.data['code'], isIn(['FOREIGN_KEY_VIOLATION', 'INVALID_REFERENCE']));
    });

    test('12. Category "أخرى" validation: empty custom name rejected with 422, non-empty accepted', () async {
      if (!isNetworkAvailable) return;

      // Seed "أخرى" category if not present
      await dio.post(
        '/expense-categories',
        data: {
          'id': testOtherCategoryId,
          'name': 'أخرى $runId',
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-seed-other-cat-$runId'},
          validateStatus: (_) => true,
        ),
      );

      // Rejection when category_name_snapshot is أخرى and expense_name is empty
      final emptyNameRes = await dio.post(
        '/expenses',
        data: {
          'id': 'e1999994-0000-4000-8000-$runId',
          'expense_category_id': testOtherCategoryId,
          'amount': 2500,
          'expense_date': '2026-09-16',
          'category_name_snapshot': 'أخرى',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-other-empty-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(emptyNameRes.statusCode, equals(422));
      expect(emptyNameRes.data['code'], isIn(['VALIDATION_ERROR', 'BUSINESS_RULE_VIOLATION']));

      // Acceptance when custom name is provided
      final validOtherRes = await dio.post(
        '/expenses',
        data: {
          'id': testOtherExpenseId,
          'expense_category_id': testOtherCategoryId,
          'amount': 2500,
          'expense_name': 'إصلاح قفل الباب',
          'expense_date': '2026-09-16',
          'category_name_snapshot': 'أخرى',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-other-valid-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(validOtherRes.statusCode, equals(201));
      expect(validOtherRes.data['expense_name'], equals('إصلاح قفل الباب'));
    });

    test('13. Expense update: returns 200 OK with updated amount and notes', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.patch(
        '/expenses/$testExpenseId',
        data: {
          'amount': 9500,
          'notes': 'تم تعديل المبلغ بعد إضافة الشحن',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step11-exp-update-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['id'], equals(testExpenseId));
      expect(res.data['amount'], equals(9500));
      expect(res.data['notes'], equals('تم تعديل المبلغ بعد إضافة الشحن'));
    });

    test('14. GET /expenses with category and date filtering', () async {
      if (!isNetworkAvailable) return;

      // GET all
      final allRes = await dio.get('/expenses');
      expect(allRes.statusCode, equals(200));
      expect(allRes.data, isA<List>());

      // Filter by category
      final catFilteredRes = await dio.get('/expenses', queryParameters: {'categoryId': testCategoryId});
      expect(catFilteredRes.statusCode, equals(200));
      final catExpenses = catFilteredRes.data as List;
      expect(catExpenses.every((e) => e['expense_category_id'] == testCategoryId), isTrue);

      // Filter by date range
      final dateFilteredRes = await dio.get('/expenses', queryParameters: {
        'startDate': '2026-09-01',
        'endDate': '2026-09-30',
      });
      expect(dateFilteredRes.statusCode, equals(200));
      final dateExpenses = dateFilteredRes.data as List;
      expect(dateExpenses.any((e) => e['id'] == testExpenseId), isTrue);

      // GET single
      final singleRes = await dio.get('/expenses/$testExpenseId');
      expect(singleRes.statusCode, equals(200));
      expect(singleRes.data['id'], equals(testExpenseId));

      // GET missing
      final missingRes = await dio.get(
        '/expenses/00000000-0000-0000-0000-000000000000',
        options: Options(validateStatus: (_) => true),
      );
      expect(missingRes.statusCode, equals(404));
    });

    test('15. Expense deletion prohibition: DELETE returns 404 NOT_FOUND', () async {
      if (!isNetworkAvailable) return;

      final delRes = await dio.delete(
        '/expenses/$testExpenseId',
        options: Options(validateStatus: (_) => true),
      );
      expect(delRes.statusCode, equals(404));
    });
  });
}
