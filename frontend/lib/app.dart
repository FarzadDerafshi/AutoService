import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/locale/locale_provider.dart';
import 'core/locale/tone_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/application/auth_provider.dart';
import 'generated/app_localizations.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/catalog/presentation/catalog_screen.dart';
import 'features/clients/presentation/clients_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/shop/presentation/profile_screen.dart';
import 'features/vehicles/presentation/vehicle_history_screen.dart';
import 'features/vehicles/presentation/vehicles_screen.dart';
import 'features/work_orders/application/work_orders_provider.dart';
import 'features/work_orders/presentation/work_order_form_screen.dart';
import 'features/work_orders/presentation/work_orders_screen.dart';

/// Notifies GoRouter to re-evaluate `redirect` whenever auth state changes
/// (login/logout/initial-token-check resolving), without recreating the
/// router itself on every widget rebuild.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/work-orders',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final goingToAuth = loc == '/login' || loc == '/register';

      if (authState.isLoading) return null; // still resolving stored token
      final isLoggedIn = authState.valueOrNull != null;

      if (!isLoggedIn && !goingToAuth) return '/login';
      if (isLoggedIn && goingToAuth) return '/work-orders';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/work-orders/new',
        builder: (context, state) => const WorkOrderFormScreen(),
      ),
      GoRoute(
        path: '/work-orders/:id/edit',
        builder: (context, state) => _WorkOrderEditRoute(workOrderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/work-orders/:id',
        builder: (context, state) => WorkOrderDetailScreen(workOrderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/history',
        builder: (context, state) => VehicleHistoryScreen(vehicleId: state.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/work-orders',
            builder: (context, state) => WorkOrdersScreen(initialId: state.uri.queryParameters['id']),
          ),
          GoRoute(path: '/clients', builder: (context, state) => const ClientsScreen()),
          GoRoute(
            path: '/vehicles',
            builder: (context, state) => VehiclesScreen(clientId: state.uri.queryParameters['clientId']),
          ),
          GoRoute(path: '/catalog', builder: (context, state) => const CatalogScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

/// Loads the WorkOrder for :id before handing off to the (create/edit) form,
/// since WorkOrderFormScreen needs the full object, not just an id.
class _WorkOrderEditRoute extends ConsumerWidget {
  const _WorkOrderEditRoute({required this.workOrderId});
  final String workOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(workOrderDetailProvider(workOrderId));
    return orderAsync.when(
      data: (order) => WorkOrderFormScreen(existing: order),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Failed to load work order: $error'))),
    );
  }
}

class AutoServiceApp extends ConsumerWidget {
  const AutoServiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    final baseLocale = ref.watch(localeProvider);
    final tone = ref.watch(toneProvider);
    // "Corporate" tone is implemented as a locale country-code variant (the
    // 'CP' suffix) so every existing AppLocalizations.of(context)!.xyz call
    // site keeps working unchanged — see core/locale/tone_provider.dart.
    final effectiveLocale =
        tone == AppTone.corporate ? Locale(baseLocale.languageCode, 'CP') : baseLocale;

    return MaterialApp.router(
      title: 'GarajOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: effectiveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
