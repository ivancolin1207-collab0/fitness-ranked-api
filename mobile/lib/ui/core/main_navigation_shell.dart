import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/ble_heart_rate_service.dart';
import '../../data/models/biometric_models.dart';
import '../../data/repositories/fitness_repository.dart';
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
  String? _activeUserId;
  final List<AiCoachChatMessageModel> _chatHistory = <AiCoachChatMessageModel>[];
  List<String> _suggestedPrompts = const <String>[
    '¿Qué puedo hacer para subir de peso limpio?',
    'Ajusta mis series y RPE para la rutina de hoy',
    '¿Qué me recomiendas cenar para bajar mi estrés?',
    '¿Cuánta agua me falta antes de entrenar?',
  ];

  @override
  void initState() {
    super.initState();
    _activeUserId = widget.authViewModel.currentUser?.id;
    widget.authViewModel.addListener(_onAuthUserChanged);
    widget.homeViewModel.resetForUserSwitch();
    widget.workoutViewModel.resetForUserSwitch();
    widget.homeViewModel.initializeDashboard();
    widget.workoutViewModel.initializeWorkoutPlan();
    widget.arenaViewModel.loadArenaData();
    unawaited(
      BleHeartRateService.instance.autoReconnectSavedDevice(
        userId: _activeUserId,
      ),
    );
  }

  @override
  void dispose() {
    widget.authViewModel.removeListener(_onAuthUserChanged);
    super.dispose();
  }

  void _onAuthUserChanged() {
    final String? nextUserId = widget.authViewModel.currentUser?.id;
    if (nextUserId != _activeUserId) {
      _activeUserId = nextUserId;
      _chatHistory.clear();
      widget.homeViewModel.resetForUserSwitch();
      widget.workoutViewModel.resetForUserSwitch();
      if (nextUserId != null && nextUserId.isNotEmpty) {
        widget.homeViewModel.initializeDashboard();
        widget.workoutViewModel.initializeWorkoutPlan();
        widget.arenaViewModel.loadArenaData();
        unawaited(
          BleHeartRateService.instance.autoReconnectSavedDevice(
            userId: nextUserId,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildLiveAthleteContext() {
    final user = widget.authViewModel.currentUser;
    final wearable = widget.homeViewModel.wearable;
    final biometrics = widget.homeViewModel.biometrics;
    final hydration = widget.homeViewModel.hydration;
    final routine = widget.workoutViewModel.selectedRoutine;

    final double recovery = widget.homeViewModel.hasWhoopData
        ? widget.homeViewModel.recoveryScore
        : (wearable?.recoveryScore ?? 47.0);
    final double sleepPct = widget.homeViewModel.hasWhoopData
        ? widget.homeViewModel.sleepPct
        : (wearable?.sleepEfficiencyPct ?? 80.0);
    final double strain = widget.homeViewModel.hasWhoopData
        ? widget.homeViewModel.strainScore
        : (wearable?.strainScore ?? 7.4);
    final double stress = widget.homeViewModel.hasWhoopData
        ? widget.homeViewModel.stressScore
        : (wearable?.whoopStressLevel ?? 1.8);
    final String stressCat =
        stress >= 2.0 ? 'ALTO' : (stress >= 1.0 ? 'MEDIO' : 'BAJO');

    final String rawFullName = user?.fullName?.trim() ?? '';
    return <String, dynamic>{
      'athlete_name': rawFullName.isNotEmpty
          ? rawFullName
          : (user?.username ?? 'Atleta'),
      'weight_kg': biometrics?.weightKg ?? 78.0,
      'lean_body_mass_kg': biometrics?.leanBodyMassKg ?? 65.0,
      'fat_percentage': biometrics?.fatPercentage ?? 14.8,
      'wearable_source': widget.homeViewModel.preferredWearable,
      'recovery_score': recovery,
      'sleep_performance_pct': sleepPct,
      'strain_score': strain,
      'stress_level': stress,
      'stress_category': stressCat,
      'hrv_ms': wearable?.hrvMs ?? 64.0,
      'resting_hr': wearable?.restingHr ?? 62,
      'hydration_consumed_ml': hydration?.totalMl ?? 0,
      'hydration_goal_ml': hydration?.recommendedGoalMl ?? 2800,
      'scheduled_routine_name': routine != null
          ? '${routine.name} (${routine.focusGroup})'
          : 'Sesión de Fuerza Programada',
    };
  }

  void _openTacticalCenterModal(BuildContext context) {
    final FitnessRepository repository = context.read<FitnessRepository>();
    final Map<String, dynamic> initialContext = _buildLiveAthleteContext();

    if (_chatHistory.isEmpty) {
      final String name = initialContext['athlete_name'] as String;
      final double rec = (initialContext['recovery_score'] as num).toDouble();
      final double sleep =
          (initialContext['sleep_performance_pct'] as num).toDouble();
      final double strain = (initialContext['strain_score'] as num).toDouble();
      final double stress = (initialContext['stress_level'] as num).toDouble();
      final String stressCat = initialContext['stress_category'] as String;
      final int hyd = (initialContext['hydration_consumed_ml'] as num).toInt();
      final int hydGoal = (initialContext['hydration_goal_ml'] as num).toInt();
      final String routineName =
          initialContext['scheduled_routine_name'] as String;

      _chatHistory.add(
        AiCoachChatMessageModel(
          role: 'assistant',
          content:
              'Atleta: $name • Telemetría activa:\n'
              '• Recuperación: ${rec.round()}% | Sueño: ${sleep.round()}%\n'
              '• Esfuerzo (Strain): ${strain.toStringAsFixed(1)} | Estrés: ${stress.toStringAsFixed(1)} ($stressCat)\n'
              '• Hidratación: $hyd / $hydGoal ml | Rutina: $routineName\n\n'
              'Solicita ajustes de RPE, cargas, superávit nutricional o protocolo de descanso.',
          timestamp: DateTime.now(),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _TacticalCenterBottomSheet(
          repository: repository,
          chatHistory: _chatHistory,
          initialSuggestedPrompts: _suggestedPrompts,
          contextBuilder: _buildLiveAthleteContext,
          onPromptsUpdated: (List<String> updated) {
            _suggestedPrompts = updated;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
      HomeScreen(
        viewModel: widget.homeViewModel,
        authViewModel: widget.authViewModel,
        onOpenTacticalCenter: () => _openTacticalCenterModal(context),
      ),
      LiveWorkoutScreen(
        viewModel: widget.workoutViewModel,
        onOpenTacticalCenter: () => _openTacticalCenterModal(context),
      ),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: ApexTheme.cardBorder, width: 1.0),
          ),
        ),
        child: NavigationBar(
          backgroundColor: ApexTheme.cardGraphite,
          surfaceTintColor: Colors.transparent,
          indicatorColor: ApexTheme.secondarySurface,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int idx) {
            setState(() {
              _selectedIndex = idx;
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.insights_outlined, color: ApexTheme.textMuted),
              selectedIcon: Icon(
                Icons.insights_rounded,
                color: ApexTheme.textPrimary,
              ),
              label: 'Readiness',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.fitness_center_outlined,
                color: ApexTheme.textMuted,
              ),
              selectedIcon: Icon(
                Icons.fitness_center_rounded,
                color: ApexTheme.textPrimary,
              ),
              label: 'Entreno Vivo',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.emoji_events_outlined,
                color: ApexTheme.textMuted,
              ),
              selectedIcon: Icon(
                Icons.emoji_events_rounded,
                color: ApexTheme.textPrimary,
              ),
              label: 'Arena ELO',
            ),
          ],
        ),
      ),
    );
  }
}

class _TacticalCenterBottomSheet extends StatefulWidget {
  final FitnessRepository repository;
  final List<AiCoachChatMessageModel> chatHistory;
  final List<String> initialSuggestedPrompts;
  final Map<String, dynamic> Function() contextBuilder;
  final ValueChanged<List<String>> onPromptsUpdated;

  const _TacticalCenterBottomSheet({
    required this.repository,
    required this.chatHistory,
    required this.initialSuggestedPrompts,
    required this.contextBuilder,
    required this.onPromptsUpdated,
  });

  @override
  State<_TacticalCenterBottomSheet> createState() =>
      _TacticalCenterBottomSheetState();
}

class _TacticalCenterBottomSheetState
    extends State<_TacticalCenterBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  late List<String> _prompts;

  @override
  void initState() {
    super.initState();
    _prompts = List<String>.from(widget.initialSuggestedPrompts);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage(String rawText) async {
    final String text = rawText.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    final AiCoachChatMessageModel userMsg = AiCoachChatMessageModel(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      widget.chatHistory.add(userMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final Map<String, dynamic> liveContext = widget.contextBuilder();
      final AiCoachChatResponseModel response =
          await widget.repository.sendAiCoachChat(
        message: text,
        history: widget.chatHistory,
        athleteContext: liveContext,
      );

      if (!mounted) return;
      setState(() {
        widget.chatHistory.add(
          AiCoachChatMessageModel(
            role: 'assistant',
            content: response.reply,
            timestamp: DateTime.now(),
          ),
        );
        if (response.suggestedPrompts.isNotEmpty) {
          _prompts = response.suggestedPrompts;
          widget.onPromptsUpdated(_prompts);
        }
        _isSending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        widget.chatHistory.add(
          AiCoachChatMessageModel(
            role: 'assistant',
            content:
                'Mantén las cargas prescritas en RPE 8.0, asegura superávit proteico (2.2 g/kg) y completa tu meta de hidratación.',
            timestamp: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> ctx = widget.contextBuilder();
    final double rec = (ctx['recovery_score'] as num).toDouble();
    final double sleep = (ctx['sleep_performance_pct'] as num).toDouble();
    final double strain = (ctx['strain_score'] as num).toDouble();
    final double stress = (ctx['stress_level'] as num).toDouble();
    final int hyd = (ctx['hydration_consumed_ml'] as num).toInt();
    final int hydGoal = (ctx['hydration_goal_ml'] as num).toInt();
    final Color recColor = ApexTheme.readinessColor(rec);

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (BuildContext context, ScrollController sheetScroll) {
          return Container(
            decoration: BoxDecoration(
              color: ApexTheme.obsidianBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border.all(
                color: ApexTheme.cardBorder,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Cabecera Técnica Pitwall
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: ApexTheme.cardGraphite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    border: Border(
                      bottom: BorderSide(color: ApexTheme.cardBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 3,
                        decoration: BoxDecoration(
                          color: ApexTheme.secondaryBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: ApexTheme.secondarySurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ApexTheme.secondaryBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: ApexTheme.textPrimary,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'CENTRO TÁCTICO • DIRECTOR DE RENDIMIENTO',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: ApexTheme.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Telemetría fisiológica, prescripción de cargas y nutrición deportiva',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: ApexTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: ApexTheme.textMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          spacing: 6,
                          children: <Widget>[
                            _PitwallBadge(
                              label: 'REC ${rec.round()}%',
                              color: recColor,
                            ),
                            _PitwallBadge(
                              label: 'SUEÑO ${sleep.round()}%',
                              color: ApexTheme.textPrimary,
                            ),
                            _PitwallBadge(
                              label: 'STRAIN ${strain.toStringAsFixed(1)}',
                              color: ApexTheme.warningAmber,
                            ),
                            _PitwallBadge(
                              label: 'ESTRÉS ${stress.toStringAsFixed(1)}',
                              color: stress >= 2.0
                                  ? ApexTheme.deloadCrimson
                                  : ApexTheme.readinessGreen,
                            ),
                            _PitwallBadge(
                              label: 'AGUA $hyd/$hydGoal ML',
                              color: ApexTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Hilo de conversación técnica
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: widget.chatHistory.length + (_isSending ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == widget.chatHistory.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ApexTheme.textPrimary,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Procesando telemetría y cálculo fisiológico...',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: ApexTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final AiCoachChatMessageModel msg =
                          widget.chatHistory[index];
                      final bool isUser = msg.role == 'user';

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.84,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? ApexTheme.secondarySurface
                                : ApexTheme.cardGraphite,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUser
                                  ? ApexTheme.secondaryBorder
                                  : ApexTheme.cardBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            msg.content,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: ApexTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Consultas tácticas rápidas
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _prompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final String prompt = _prompts[i];
                      return ActionChip(
                        backgroundColor: ApexTheme.secondarySurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(
                            color: ApexTheme.secondaryBorder,
                          ),
                        ),
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ApexTheme.textPrimary,
                          ),
                        ),
                        onPressed:
                            _isSending ? null : () => _sendMessage(prompt),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Input de comando
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: const BoxDecoration(
                      color: ApexTheme.cardGraphite,
                      border: Border(
                        top: BorderSide(color: ApexTheme.cardBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Consulta ajustes de RPE, macros o recuperación...',
                              hintStyle: const TextStyle(
                                fontSize: 11.5,
                                color: ApexTheme.textMuted,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: ApexTheme.obsidianBg,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: ApexTheme.cardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: ApexTheme.voltAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          width: 42,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: ApexTheme.voltAccent,
                              foregroundColor: ApexTheme.obsidianBg,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isSending
                                ? null
                                : () => _sendMessage(_inputController.text),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PitwallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PitwallBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ApexTheme.obsidianBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ApexTheme.secondaryBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
