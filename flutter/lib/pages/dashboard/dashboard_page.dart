import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: '首页'),
    NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: '发现'),
    NavigationDestination(
        icon: Icon(Icons.notifications_outlined),
        selectedIcon: Icon(Icons.notifications),
        label: '通知'),
    NavigationDestination(
        icon: Icon(Icons.person_outlined),
        selectedIcon: Icon(Icons.person),
        label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _PlaceholderTab(label: '首页 — 开发中'),
          _PlaceholderTab(label: '发现 — 开发中'),
          _PlaceholderTab(label: '通知 — 开发中'),
          _PlaceholderTab(label: '我的 — 开发中'),
        ],
      ),
      bottomNavigationBar: _withCompactOhosBottomInset(
        context,
        NavigationBar(
          height: 64,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: _destinations,
        ),
      ),
    );
  }
}

Widget _withCompactOhosBottomInset(BuildContext context, Widget child) {
  if (!isOhos) {
    return child;
  }

  final media = MediaQuery.of(context);
  final padding = media.padding;
  return MediaQuery(
    data: media.copyWith(
      padding: padding.copyWith(bottom: padding.bottom == 0 ? 0 : 8),
    ),
    child: child,
  );
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
