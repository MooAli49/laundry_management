import '../entities/carpet_size.dart';

abstract class CarpetSizeRepository {
  Future<CarpetSize> createCarpetSize(CarpetSize carpetSize);
  Future<CarpetSize> updateCarpetSize(CarpetSize carpetSize);
  Future<CarpetSize?> getCarpetSizeById(String id);
  Future<List<CarpetSize>> getActiveCarpetSizes();
  Future<List<CarpetSize>> getAllCarpetSizes();
  Future<void> activateCarpetSize(String id);
  Future<void> deactivateCarpetSize(String id);
}
