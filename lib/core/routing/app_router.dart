import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/routing/routes.dart';
import 'package:laundry_management/features/home/presentation/root_screen.dart';
import 'package:laundry_management/features/orders/presentation/add_new_order_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.home,
        builder: (context, state) => const RootScreen(),
      ),
      GoRoute(
        path: Routes.addNewOrder,
        name: Routes.addNewOrder,
        builder: (context, state) => const AddNewOrderScreen(),
      ),
    ],
  );
}
