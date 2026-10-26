import 'package:flutter/material.dart';

import 'screens/activity_feed_screen.dart';
import 'screens/add_item_sheet.dart';
import 'screens/freezer_overview_screen.dart';
import 'screens/household_settings_screen.dart';
import 'services/app_state.dart';
import 'widgets/eiszeit_visual_effects.dart';

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
        scaffoldBackgroundColor: const Color(0xFFEAF2F8),
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
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF071324),
                    Color(0xFF0D2745),
                    Color(0xFF005691),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33002B49),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      // Lustiges 3D Eiszeit-Mammut App-Icon im leuchtenden Eis-Rahmen
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/eiszeit_app_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.ac_unit_rounded,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'EISZEIT',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'NOSTR SYNC',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF00E5FF),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${appState.currentUser.displayName} (${isAdmin ? "Host/Admin" : "Mitglied"}) • ${appState.household.householdName}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Nostr Sync ausführen',
                        onPressed: () async {
                          await appState.manualSyncNow();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                appState.lastSyncMessage ?? 'Nostr Sync abgeschlossen.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.sync_rounded, color: Color(0xFF00E5FF)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: _selectedIndex == 0
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF005691),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddItemSheet(appState: appState),
                    );
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text(
                    'Einlagern ("Rein")',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  FreezerOverviewScreen(appState: appState),
                  ActivityFeedScreen(appState: appState),
                  HouseholdSettingsScreen(appState: appState),
                ],
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: IcicleRow(height: 12),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF005691).withValues(alpha: 0.14),
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: appState.expiringOrExpiredItems.isNotEmpty,
                  label: Text('${appState.expiringOrExpiredItems.length}'),
                  child: const Icon(Icons.kitchen_outlined),
                ),
                selectedIcon: const Icon(Icons.kitchen, color: Color(0xFF005691)),
                label: 'Gefrierschrank',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history, color: Color(0xFF005691)),
                label: 'Rein/Raus-Log',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: true,
                  backgroundColor: const Color(0xFF005691),
                  label: Text('${appState.household.activeMembers.length}'),
                  child: const Icon(Icons.groups_outlined),
                ),
                selectedIcon: const Icon(Icons.groups, color: Color(0xFF005691)),
                label: 'Familie & R2',
              ),
            ],
          ),
        );
      },
    );
  }
}
