import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/dashboard'),
    _NavItem(icon: Icons.medical_services_outlined, label: 'Doctors', route: '/doctors'),
    _NavItem(icon: Icons.people_outline, label: 'Users', route: '/users'),
    _NavItem(icon: Icons.location_city_outlined, label: 'Clinics', route: '/clinics'),
    _NavItem(icon: Icons.calendar_today_outlined, label: 'Appointments', route: '/appointments'),
    _NavItem(icon: Icons.category_outlined, label: 'Categories', route: '/categories'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;

    // Responsive: drawer on small screens, rail on medium, nav on large
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1200;
    final isMedium = width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationDrawer(
              selectedIndex: _selectedIndex(location),
              onDestinationSelected: (i) => context.go(_navItems[i].route),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 24, 16, 10),
                  child: Text('DoctorBook Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ..._navItems.map(
                  (item) => NavigationDrawerDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    const storage = FlutterSecureStorage();
                    await storage.deleteAll();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    if (isMedium) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex(location),
              onDestinationSelected: (i) => context.go(_navItems[i].route),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)))
                  .toList(),
              labelType: NavigationRailLabelType.all,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (i) => context.go(_navItems[i].route),
        destinations: _navItems
            .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
      ),
    );
  }

  int _selectedIndex(String location) {
    for (var i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}
