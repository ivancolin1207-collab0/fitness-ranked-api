import 'package:flutter/material.dart';
import '../features/arena/view_models/ranked_arena_view_model.dart';
import '../features/arena/views/ranked_arena_screen.dart';
import '../features/auth/view_models/auth_view_model.dart';
import '../features/home/view_models/home_view_model.dart';
import '../features/home/views/home_screen.dart';
import '../features/workout/view_models/live_workout_view_model.dart';
import '../features/workout/views/live_workout_screen.dart';
import 'app_theme.dart';

class MainNavigationShell extends StatefulWidget {
  final AuthViewModel authViewModel;
  final HomeViewModel homeViewModel;
  final LiveWorkoutViewModel workoutViewModel;
  final RankedArenaViewModel arenaViewModel;

  const MainNavigationShell({
    super.key,
    required this.authViewModel,
    required this.homeViewModel,
    required this.workoutViewModel,
    required this.arenaViewModel,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.homeViewModel.initializeDashboard();
    widget.workoutViewModel.initializeWorkoutPlan();
    widget.arenaViewModel.loadArenaData();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
      HomeScreen(
        viewModel: widget.homeViewModel,
        authViewModel: widget.authViewModel,
      ),
      LiveWorkoutScreen(viewModel: widget.workoutViewModel),
      RankedArenaScreen(
        viewModel: widget.arenaViewModel,
        authViewModel: widget.authViewModel,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: ApexTheme.cardGraphite,
        indicatorColor: ApexTheme.voltAccent.withValues(alpha: 0.22),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(
              Icons.insights_rounded,
              color: ApexTheme.voltAccent,
            ),
            label: 'Readiness',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(
              Icons.fitness_center_rounded,
              color: ApexTheme.voltAccent,
            ),
            label: 'Entreno Vivo',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(
              Icons.emoji_events_rounded,
              color: ApexTheme.voltAccent,
            ),
            label: 'Arena ELO',
          ),
        ],
      ),
    );
  }
}
