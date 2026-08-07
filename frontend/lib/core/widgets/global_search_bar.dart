import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/search/application/search_provider.dart';
import '../../features/search/data/search_repository.dart';
import '../../generated/app_localizations.dart';
import '../utils/plate_formatter.dart';

/// Persistent global search bar (see architecture doc 4.3): queries
/// /api/v1/search with a ~300ms debounce and shows sectioned results,
/// prioritizing license-plate matches above name/phone matches (the API
/// already orders vehicles that way; this widget just renders vehicles first).
class GlobalSearchBar extends ConsumerStatefulWidget {
  const GlobalSearchBar({super.key});

  @override
  ConsumerState<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends ConsumerState<GlobalSearchBar> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;
  SearchResults? _results;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = null);
      _removeOverlay();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query.trim()),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(searchRepositoryProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      _showOverlay();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 360,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: _buildResultsList(),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _dismiss() {
    _controller.clear();
    setState(() => _results = null);
    _removeOverlay();
  }

  Widget _buildResultsList() {
    final results = _results;
    if (results == null || results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No matches'),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final vehicle in results.vehicles)
            ListTile(
              dense: true,
              leading: const Icon(Icons.directions_car),
              title: Text(formatPlateDisplay(vehicle.licensePlate)),
              subtitle: Text(vehicle.displayName),
              onTap: () {
                _dismiss();
                context.push('/vehicles/${vehicle.id}/history');
              },
            ),
          for (final client in results.clients)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person),
              title: Text(client.fullName),
              subtitle: Text(client.phone ?? client.email ?? ''),
              onTap: () {
                _dismiss();
                context.push('/vehicles?clientId=${client.id}');
              },
            ),
          for (final order in results.workOrders)
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long),
              title: Text('Order #${order.orderNo}'),
              subtitle: Text(order.status),
              onTap: () {
                _dismiss();
                context.push('/work-orders/${order.id}');
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 320,
        height: 40,
        child: TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            hintText: AppLocalizations.of(context)!.globalSearchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _dismiss,
                        )
                      : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
