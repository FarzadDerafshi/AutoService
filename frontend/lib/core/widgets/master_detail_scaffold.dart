import 'package:flutter/material.dart';

/// One shared widget tree, two arrangements, switched by breakpoint — not two
/// separate screens — so state (selected work order, filters) is never lost
/// when the window is resized (e.g. rotating a tablet, resizing a browser).
class MasterDetailScaffold extends StatelessWidget {
  final Widget masterPanel;
  final Widget? detailPanel;
  final String emptyDetailMessage;

  const MasterDetailScaffold({
    required this.masterPanel,
    required this.detailPanel,
    this.emptyDetailMessage = 'Select an item to view its details',
    super.key,
  });

  static const double desktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= desktopBreakpoint;

        if (isWide) {
          return Row(
            children: [
              SizedBox(width: constraints.maxWidth * 0.35, child: masterPanel),
              const VerticalDivider(width: 1),
              Expanded(
                child: detailPanel ??
                    Center(
                      child: Text(
                        emptyDetailMessage,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                    ),
              ),
            ],
          );
        }

        // Mobile/narrow: master list is the primary screen. The caller is
        // responsible for pushing a full-screen detail route on selection
        // (see work_orders_screen.dart) so narrow layouts get a native
        // drill-down feel instead of a squeezed split view.
        return masterPanel;
      },
    );
  }
}
