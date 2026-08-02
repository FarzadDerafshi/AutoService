import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/tone_provider.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/reports/application/reports_provider.dart';
import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import 'global_search_bar.dart';
import 'master_detail_scaffold.dart';
import 'streak_badge.dart';

String _initial(String? name) => (name == null || name.isEmpty) ? '?' : name[0].toUpperCase();

/// Persistent shell around every authenticated screen. Same routing/rail
/// structure as before — restyled for the dark "garage" theme and carrying
/// the Grease Monkey streak badge in the AppBar.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;

  int _selectedIndex(List<({String path, IconData icon, String label})> destinations) {
    final index = destinations.indexWhere((d) => location.startsWith(d.path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width >= MasterDetailScaffold.desktopBreakpoint;
    final user = ref.watch(currentUserProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentTone = ref.watch(toneProvider);
    final streakDays = ref.watch(streakDaysProvider).valueOrNull ?? 0;

    final destinations = [
      (path: '/work-orders', icon: Icons.receipt_long, label: l.workOrders),
      (path: '/clients', icon: Icons.people, label: l.clients),
      (path: '/vehicles', icon: Icons.directions_car, label: l.vehicles),
      (path: '/catalog', icon: Icons.build, label: l.catalog),
      (path: '/reports', icon: Icons.bar_chart, label: l.reports),
    ];

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/branding/logo.png', height: 28),
          const SizedBox(width: 10),
          Text(l.appTitle),
        ],
      ),
      actions: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: GlobalSearchBar()),
        const SizedBox(width: 14),
        StreakBadge(days: streakDays),
        const SizedBox(width: 14),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundColor: AppColors.surfaceRaised,
            child: Text(_initial(user?.fullName), style: const TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.w700)),
          ),
          onSelected: (action) async {
            if (action == 'profile') {
              context.go('/profile');
            } else if (action == 'logout') {
              ref.read(authControllerProvider.notifier).logout();
            } else if (action == 'lang_en') {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
            } else if (action == 'lang_tr') {
              ref.read(localeProvider.notifier).setLocale(const Locale('tr'));
            } else if (action == 'tone_corporate') {
              ref.read(toneProvider.notifier).setTone(AppTone.corporate);
            } else if (action == 'tone_street') {
              ref.read(toneProvider.notifier).setTone(AppTone.street);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(enabled: false, child: Text(user?.fullName ?? '')),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'profile',
              child: Row(children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 10),
                Text(l.profile),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(l.language, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            PopupMenuItem(
              value: 'lang_en',
              child: Row(children: [
                const Text('🇬🇧  English'),
                if (currentLocale.languageCode == 'en') ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ]),
            ),
            PopupMenuItem(
              value: 'lang_tr',
              child: Row(children: [
                const Text('🇹🇷  Türkçe'),
                if (currentLocale.languageCode == 'tr') ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(l.voiceToneLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            PopupMenuItem(
              value: 'tone_corporate',
              child: Row(children: [
                const Icon(Icons.business_center, size: 16),
                const SizedBox(width: 10),
                Text(l.toneCorporate),
                if (currentTone == AppTone.corporate) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ]),
            ),
            PopupMenuItem(
              value: 'tone_street',
              child: Row(children: [
                const Icon(Icons.build, size: 16),
                const SizedBox(width: 10),
                Text(l.toneStreet),
                if (currentTone == AppTone.street) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'logout', child: Text(l.logOut)),
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
              selectedIndex: _selectedIndex(destinations),
              onDestinationSelected: (index) => context.go(destinations[index].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(destinations),
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
