import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/liquid_glass_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  int _tabIndex(String location) {
    if (location.startsWith('/activity')) return 1;
    if (location.startsWith('/progression')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _tabIndex(location),
        onTap: (i) {
          if (i == 0) context.go('/today');
          if (i == 1) context.go('/activity');
          if (i == 2) context.go('/progression');
        },
      ),
    );
  }
}
