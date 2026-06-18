import '../../domain/entities/import_result.dart';
import '../../../inventory/domain/failures/inventory_failure.dart';

abstract class MigrationRepository {
  Future<(ImportResult?, InventoryFailure?)> importCategories(
      List<Map<String, dynamic>> rows);
  Future<(ImportResult?, InventoryFailure?)> importBrands(
      List<Map<String, dynamic>> rows);
  Future<(ImportResult?, InventoryFailure?)> importProducts(
      List<Map<String, dynamic>> rows);
  Future<(ImportResult?, InventoryFailure?)> importStock(
      String branchId, List<Map<String, dynamic>> rows);
}
