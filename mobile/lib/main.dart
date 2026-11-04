import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/fitness_repository.dart';
import 'data/services/api_client_service.dart';
import 'data/services/health_connect_service.dart';
import 'data/services/secure_storage_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/core/main_navigation_shell.dart';
import 'ui/features/arena/view_models/ranked_arena_view_model.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/auth_screen.dart';
import 'ui/features/auth/views/profile_setup_screen.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/workout/view_models/live_workout_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final ApiClientService apiClient = ApiClientService();
  final HealthConnectService healthService = HealthConnectService();
  const SecureStorageService storageService = SecureStorageService();

  final FitnessRepository repository = FitnessRepository(
    apiClient: apiClient,
    healthConnectService: healthService,
    storageService: storageService,
  );

  runApp(ApexMetrixApp(repository: repository));
}

class ApexMetrixApp extends StatefulWidget {
  final FitnessRepository repository;

  const ApexMetrixApp({
    super.key,
    required this.repository,
  });

  @override
  State<ApexMetrixApp> createState() => _ApexMetrixAppState();
}

class _ApexMetrixAppState extends State<ApexMetrixApp> {
  late final AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(repository: widget.repository)
      ..bootstrapSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FitnessRepository>.value(value: widget.repository),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(repository: widget.repository),
        ),
        ChangeNotifierProvider<LiveWorkoutViewModel>(
          create: (_) => LiveWorkoutViewModel(repository: widget.repository),
        ),
        ChangeNotifierProvider<RankedArenaViewModel>(
          create: (_) => RankedArenaViewModel(repository: widget.repository),
        ),
      ],
      child: MaterialApp(
        title: 'ApexMetrix Ranked Fitness',
        debugShowCheckedModeBanner: false,
        theme: ApexTheme.darkTheme,
        home: Consumer4<AuthViewModel, HomeViewModel, LiveWorkoutViewModel,
            RankedArenaViewModel>(
          builder: (
            BuildContext context,
            AuthViewModel authVm,
            HomeViewModel homeVm,
            LiveWorkoutViewModel workoutVm,
            RankedArenaViewModel arenaVm,
            _,
          ) {
            if (authVm.isBootstrapping) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!authVm.isAuthenticated) {
              return AuthScreen(viewModel: authVm);
            }

            if (authVm.needsOnboarding) {
              return ProfileSetupScreen(viewModel: authVm);
            }

            return MainNavigationShell(
              authViewModel: authVm,
              homeViewModel: homeVm,
              workoutViewModel: workoutVm,
              arenaViewModel: arenaVm,
            );
          },
        ),
      ),
    );
  }
}
