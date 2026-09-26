import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/repositories/expense_category_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/expense_categories_management_cubit.dart';

class FakeExpenseCategoryRepository implements ExpenseCategoryRepository {
  bool shouldThrow = false;
  final List<ExpenseCategory> categories = [];

  @override
  Future<ExpenseCategory> createCategory(ExpenseCategory category) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    categories.add(category);
    return category;
  }

  @override
  Future<ExpenseCategory> updateCategory(ExpenseCategory category) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) categories[idx] = category;
    return category;
  }

  @override
  Future<List<ExpenseCategory>> getAllCategories() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return List.from(categories);
  }

  @override
  Future<List<ExpenseCategory>> getActiveCategories() async {
    return categories.where((c) => c.isActive).toList();
  }

  @override
  Future<ExpenseCategory?> getCategoryById(String id) async {
    final matches = categories.where((c) => c.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> activateCategory(String id) async {
    final idx = categories.indexWhere((c) => c.id == id);
    if (idx != -1) categories[idx] = categories[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateCategory(String id) async {
    final idx = categories.indexWhere((c) => c.id == id);
    if (idx != -1) categories[idx] = categories[idx].copyWith(isActive: false);
  }
}

void main() {
  late FakeExpenseCategoryRepository repository;
  late ExpenseCategoriesManagementCubit cubit;

  setUp(() {
    repository = FakeExpenseCategoryRepository();
    cubit = ExpenseCategoriesManagementCubit(
      expenseCategoryRepository: repository,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('ExpenseCategoriesManagementCubit Tests', () {
    test(
      'createCategory validates required name and creates category',
      () async {
        final failRes = await cubit.createCategory('');
        expect(failRes, isFalse);
        expect(
          cubit.state.errorMessage,
          AppStrings.expenseCategoryNameRequired,
        );

        final successRes = await cubit.createCategory('فواتير كهرباء');
        expect(successRes, isTrue);
        expect(cubit.state.categories.length, 1);
        expect(cubit.state.categories.first.name, 'فواتير كهرباء');
      },
    );

    test('updateCategory updates existing category name', () async {
      await cubit.createCategory('منظفات');
      final cat = cubit.state.categories.first;

      final updateRes = await cubit.updateCategory(
        cat.copyWith(name: 'منظفات ومساحيق'),
      );
      expect(updateRes, isTrue);
      expect(cubit.state.categories.first.name, 'منظفات ومساحيق');
    });

    test('activate and deactivate category', () async {
      await cubit.createCategory('صيانة');
      final id = cubit.state.categories.first.id;

      await cubit.deactivateCategory(id);
      expect(cubit.state.categories.first.isActive, isFalse);

      await cubit.activateCategory(id);
      expect(cubit.state.categories.first.isActive, isTrue);
    });
  });
}
