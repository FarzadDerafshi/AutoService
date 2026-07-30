import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_provider.dart';
import 'global_search_bar.dart';
import 'master_detail_scaffold.dart';

String _initial(String? name) => (name == null || name.isEmpty) ? '?' : name[0].toUpperCase();

const _destinations = [
  (path: '/work-orders', icon: Icons.receipt_long, label: 'Work Orders'),
  (path: '/clients', icon: Icons.people, label: 'Clients'),
  (path: '/vehicles', icon: Icons.directions_car, label: 'Vehicles'),
  (path: '/catalog', icon: Icons.build, label: 'Catalog'),
  (path: '/reports', icon: Icons.bar_chart, label: 'Reports'),
];

/// Persistent shell around every authenticated screen: nav (rail on wide
/// layouts, bottom bar on narrow) plus the global search bar in the AppBar,
/// per the architecture doc's requirement that search live in a persistent
/// header across both layouts.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;

  int get _selectedIndex {
    final index = _destinations.indexWhere((d) => location.startsWith(d.path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= MasterDetailScaffold.desktopBreakpoint;
    final user = ref.watch(currentUserProvider);

    final appBar = AppBar(
      title: const Text('AutoService'),
      actions: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: GlobalSearchBar()),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          icon: CircleAvatar(child: Text(_initial(user?.fullName))),
          onSelected: (action) {
            if (action == 'logout') ref.read(authControllerProvider.notifier).logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(enabled: false, child: Text(user?.fullName ?? '')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Text('Log out')),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => context.go(_destinations[index].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
        destinations: [
          for (final d in _destinations) NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
