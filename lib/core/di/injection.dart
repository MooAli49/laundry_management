import 'package:get_it/get_it.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // Core Local Database
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
}
