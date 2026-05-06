import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';

class AdaptiveBottomNavigationBar extends StatelessWidget {
  const AdaptiveBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.height = 64,
    this.indicatorColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final double height;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    if (!isOhos) {
      return NavigationBar(
        height: height,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        indicatorColor: indicatorColor,
        destinations: destinations,
      );
    }

    return _OhosBottomNavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
  }
}

class _OhosBottomNavigationBar extends StatelessWidget {
  const _OhosBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  static const double _contentHeight = 56;
  static const double _bottomSpacing = 12;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: _bottomSpacing),
        child: SizedBox(
          height: _contentHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _OhosNavigationItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OhosNavigationItem extends StatelessWidget {
  const _OhosNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    final child = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: color, size: 24),
            child: selected
                ? destination.selectedIcon ?? destination.icon
                : destination.icon,
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      enabled: destination.enabled,
      child: Tooltip(
        message: destination.tooltip ?? destination.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: destination.enabled ? onTap : null,
          child: child,
        ),
      ),
    );
  }
}
