import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _tabs = [
    _Tab(icon: Icons.style_outlined, label: 'Discover', path: '/discover'),
    _Tab(icon: Icons.favorite_border, label: 'Matches', path: '/matches'),
    _Tab(icon: Icons.person_outline, label: 'Profile', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => location.startsWith(t.path));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}
