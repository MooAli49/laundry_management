import '../../core/errors/failures.dart';
import '../../domain/repositories/storage_repository.dart';

class UnstoreItemInput {
  final String orderItemId;

  const UnstoreItemInput({
    required this.orderItemId,
  });
}

class UnstoreItemUseCase {
  final StorageRepository _storageRepository;

  UnstoreItemUseCase({
    required StorageRepository storageRepository,
  }) : _storageRepository = storageRepository;

  Future<void> execute(UnstoreItemInput input) async {
    if (input.orderItemId.trim().isEmpty) {
      throw const ValidationFailure('Order item ID cannot be empty');
    }

    await _storageRepository.unstoreItem(input.orderItemId);
  }
}
