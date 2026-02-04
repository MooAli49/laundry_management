import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/routing/routes.dart';
import 'package:laundry_management/features/home/presentation/root_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const RootScreen(),
      ),
    ],
  );
}
