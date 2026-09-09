import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/unstore_item_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';

class FakeStorageRepository implements StorageRepository {
  final Set<String> unstoredItemIds = {};
  bool shouldThrow = false;
  Failure? failureToThrow;

  @override
  Future<void> unstoreItem(String orderItemId) async {
    if (shouldThrow) {
      throw failureToThrow ?? const BusinessRuleFailure('Item has no active storage record to unstore');
    }
    unstoredItemIds.add(orderItemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStorageRepository storageRepo;
  late UnstoreItemUseCase useCase;

  setUp(() {
    storageRepo = FakeStorageRepository();
    useCase = UnstoreItemUseCase(storageRepository: storageRepo);
  });

  group('UnstoreItemUseCase', () {
    test('rejects empty orderItemId with ValidationFailure', () async {
      expect(
        () => useCase.execute(const UnstoreItemInput(orderItemId: '')),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => useCase.execute(const UnstoreItemInput(orderItemId: '   ')),
        throwsA(isA<ValidationFailure>()),
      );
      expect(storageRepo.unstoredItemIds, isEmpty);
    });

    test('successfully unstores valid item', () async {
      await useCase.execute(const UnstoreItemInput(orderItemId: 'item-101'));
      expect(storageRepo.unstoredItemIds, contains('item-101'));
    });

    test('propagates repository BusinessRuleFailure when item not stored', () async {
      storageRepo.shouldThrow = true;
      storageRepo.failureToThrow = const BusinessRuleFailure('Item has no active storage record to unstore');

      expect(
        () => useCase.execute(const UnstoreItemInput(orderItemId: 'item-not-stored')),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Item has no active storage record to unstore'),
          ),
        ),
      );
    });
  });
}
