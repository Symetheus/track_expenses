import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';

/// Coquille principale de l'application.
/// Contient la NavigationRail (onglets Import / Analyses) et
/// délègue le rendu du contenu à [HomeScreen] ou [AnalyticsScreen].
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Rail de navigation ────────────────────────────────────
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Paramètres',
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: Text('Import'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Analyses'),
              ),
            ],
          ),

          const VerticalDivider(thickness: 1, width: 1),

          // ── Contenu de l'onglet actif ─────────────────────────────
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: const [HomeScreen(), AnalyticsScreen()]),
          ),
        ],
      ),
    );
  }
}
