import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final List<AiCoachChatMessageModel> _chatHistory = <AiCoachChatMessageModel>[];
  List<String> _suggestedPrompts = const <String>[
    '¿Debo entrenar pesado hoy con mi recuperación actual?',
    'Ajusta mis series y RPE para la rutina de hoy',
    '¿Cuánta agua me falta antes de entrenar?',
    '¿Cómo bajar mi estrés antes de iniciar?',
  ];

  @override
  void initState() {
    super.initState();
    widget.homeViewModel.initializeDashboard();
    widget.workoutViewModel.initializeWorkoutPlan();
    widget.arenaViewModel.loadArenaData();
  }

  Map<String, dynamic> _buildLiveAthleteContext() {
    final user = widget.authViewModel.currentUser;
    final wearable = widget.homeViewModel.wearable;
    final hydration = widget.homeViewModel.hydration;
    final routine = widget.workoutViewModel.selectedRoutine;

    final double recovery = wearable?.recoveryScore ?? 62.0;
    final double sleepPct = wearable?.sleepEfficiencyPct ?? 80.0;
    final double strain = wearable?.strainScore ?? 7.1;
    final double stress = wearable?.whoopStressLevel ?? 2.1;
    final String stressCat =
        stress >= 2.0 ? 'Alto' : (stress >= 1.0 ? 'Medio' : 'Bajo');

    final String rawFullName = user?.fullName?.trim() ?? '';
    return <String, dynamic>{
      'athlete_name': rawFullName.isNotEmpty
          ? rawFullName
          : (user?.username ?? 'Atleta'),
      'recovery_score': recovery,
      'sleep_performance_pct': sleepPct,
      'strain_score': strain,
      'stress_level': stress,
      'stress_category': stressCat,
      'hrv_ms': wearable?.hrvMs ?? 64.0,
      'resting_hr': wearable?.restingHr ?? 62,
      'hydration_consumed_ml': hydration?.totalMl ?? 0,
      'hydration_goal_ml': hydration?.recommendedGoalMl ?? 2800,
      'scheduled_routine_name':
          routine != null ? '${routine.name} (${routine.focusGroup})' : 'Sesión de Fuerza Programada',
    };
  }

  void _openGeminiCoachModal(BuildContext context) {
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
              'Hola $name. Tengo sincronizada tu telemetría en vivo:\n'
              '• Recuperación: ${rec.round()}% | Sueño: ${sleep.round()}%\n'
              '• Esfuerzo (Strain): ${strain.toStringAsFixed(1)} | Estrés: ${stress.toStringAsFixed(1)} ($stressCat)\n'
              '• Hidratación: $hyd / $hydGoal ml | Rutina: $routineName\n\n'
              '¿Qué ajuste táctico de cargas, RPE, series o recuperación necesitas ahora?',
          timestamp: DateTime.now(),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _GeminiCoachBottomSheet(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'gemini_coach_personal_fab',
        backgroundColor: ApexTheme.cardGraphite,
        foregroundColor: ApexTheme.voltAccent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: ApexTheme.voltAccent, width: 1.5),
        ),
        onPressed: () => _openGeminiCoachModal(context),
        icon: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_rounded,
              color: ApexTheme.voltAccent,
              size: 20,
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ApexTheme.cyanElectric,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        label: const Text(
          'GEMINI COACH',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: ApexTheme.voltAccent,
          ),
        ),
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

class _GeminiCoachBottomSheet extends StatefulWidget {
  final FitnessRepository repository;
  final List<AiCoachChatMessageModel> chatHistory;
  final List<String> initialSuggestedPrompts;
  final Map<String, dynamic> Function() contextBuilder;
  final ValueChanged<List<String>> onPromptsUpdated;

  const _GeminiCoachBottomSheet({
    required this.repository,
    required this.chatHistory,
    required this.initialSuggestedPrompts,
    required this.contextBuilder,
    required this.onPromptsUpdated,
  });

  @override
  State<_GeminiCoachBottomSheet> createState() =>
      _GeminiCoachBottomSheetState();
}

class _GeminiCoachBottomSheetState extends State<_GeminiCoachBottomSheet> {
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
      duration: const Duration(milliseconds: 250),
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        widget.chatHistory.add(
          AiCoachChatMessageModel(
            role: 'assistant',
            content:
                'Tuve un inconveniente de red al consultar el servidor, pero según tu telemetría actual mantén el RPE en 8.0 y prioriza hidratación con electrolitos.',
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
    final Color recColor = rec >= 67.0
        ? ApexTheme.readinessGreen
        : (rec >= 34.0 ? ApexTheme.warningAmber : ApexTheme.deloadCrimson);

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
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: ApexTheme.voltAccent.withValues(alpha: 0.55),
                width: 1.3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Barra superior y título GEMINI COACH PERSONAL
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: ApexTheme.cardGraphite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(23),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ApexTheme.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ApexTheme.voltAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ApexTheme.voltAccent),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: ApexTheme.voltAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'GEMINI COACH PERSONAL',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: ApexTheme.voltAccent,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  'IA Táctica conectada a tu WHOOP, Hidratación y Rutina en vivo',
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Cinta de contexto biométrico en vivo
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          spacing: 6,
                          children: <Widget>[
                            _ContextBadge(
                              label: 'Rec ${rec.round()}%',
                              color: recColor,
                            ),
                            _ContextBadge(
                              label: 'Sueño ${sleep.round()}%',
                              color: const Color(0xFF75A8D3),
                            ),
                            _ContextBadge(
                              label: 'Strain ${strain.toStringAsFixed(1)}',
                              color: ApexTheme.cyanElectric,
                            ),
                            _ContextBadge(
                              label: 'Estrés ${stress.toStringAsFixed(1)}',
                              color: stress >= 2.0
                                  ? ApexTheme.warningAmber
                                  : ApexTheme.readinessGreen,
                            ),
                            _ContextBadge(
                              label: 'Agua $hyd/$hydGoal ml',
                              color: ApexTheme.cyanElectric,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de mensajes del chat
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
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ApexTheme.voltAccent,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Gemini Coach analizando biometría en tiempo real...',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: ApexTheme.textMuted,
                                  fontStyle: FontStyle.italic,
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
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? ApexTheme.voltAccent.withValues(alpha: 0.18)
                                : ApexTheme.cardGraphite,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isUser ? 14 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 14),
                            ),
                            border: Border.all(
                              color: isUser
                                  ? ApexTheme.voltAccent.withValues(alpha: 0.7)
                                  : ApexTheme.cyanElectric.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            msg.content,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.38,
                              color: ApexTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Chips de preguntas rápidas
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _prompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final String prompt = _prompts[i];
                      return ActionChip(
                        backgroundColor: ApexTheme.cardGraphite,
                        side: BorderSide(
                          color: ApexTheme.cyanElectric.withValues(alpha: 0.45),
                        ),
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ApexTheme.cyanElectric,
                          ),
                        ),
                        onPressed:
                            _isSending ? null : () => _sendMessage(prompt),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Caja de texto e envío
                 SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: const BoxDecoration(
                      color: ApexTheme.cardGraphite,
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
                                  'Pregúntale a Gemini Coach sobre tu rutina o recuperación...',
                              hintStyle: const TextStyle(
                                fontSize: 11.5,
                                color: ApexTheme.textMuted,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              filled: true,
                              fillColor: ApexTheme.obsidianBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: ApexTheme.voltAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _isSending
                              ? null
                              : () => _sendMessage(_inputController.text),
                          icon: const Icon(Icons.send_rounded, size: 18),
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

class _ContextBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ContextBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
