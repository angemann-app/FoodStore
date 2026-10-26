import 'package:flutter/material.dart';

import 'screens/activity_feed_screen.dart';
import 'screens/add_item_sheet.dart';
import 'screens/freezer_overview_screen.dart';
import 'screens/household_settings_screen.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  appState.initialize();
  runApp(EiszeitApp(appState: appState));
}

class EiszeitApp extends StatelessWidget {
  final AppState appState;

  const EiszeitApp({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eiszeit • FoodStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005691),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FA),
      ),
      home: EiszeitHomeShell(appState: appState),
    );
  }
}

class EiszeitHomeShell extends StatefulWidget {
  final AppState appState;

  const EiszeitHomeShell({
    super.key,
    required this.appState,
  });

  @override
  State<EiszeitHomeShell> createState() => _EiszeitHomeShellState();
}

class _EiszeitHomeShellState extends State<EiszeitHomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isAdmin = appState.isCurrentUserHost;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF005691),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.ac_unit_rounded, size: 22, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Eiszeit • FoodStore',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${appState.currentUser.displayName} (${isAdmin ? "Host/Admin" : "Mitglied"}) • ${appState.household.householdName}',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Nostr Sync ausführen',
                onPressed: () async {
                  await appState.manualSyncNow();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appState.lastSyncMessage ?? 'Nostr Sync abgeschlossen.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          floatingActionButton: _selectedIndex == 0
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF005691),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddItemSheet(appState: appState),
                    );
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Einlagern ("Rein")'),
                )
              : null,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              FreezerOverviewScreen(appState: appState),
              ActivityFeedScreen(appState: appState),
              HouseholdSettingsScreen(appState: appState),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: appState.expiringOrExpiredItems.isNotEmpty,
                  label: Text('${appState.expiringOrExpiredItems.length}'),
                  child: const Icon(Icons.kitchen_outlined),
                ),
                selectedIcon: const Icon(Icons.kitchen),
                label: 'Gefrierschrank',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Rein/Raus-Log',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: true,
                  backgroundColor: const Color(0xFF005691),
                  label: Text('${appState.household.activeMembers.length}'),
                  child: const Icon(Icons.groups_outlined),
                ),
                selectedIcon: const Icon(Icons.groups),
                label: 'Familie & R2',
              ),
            ],
          ),
        );
      },
    );
  }
}
