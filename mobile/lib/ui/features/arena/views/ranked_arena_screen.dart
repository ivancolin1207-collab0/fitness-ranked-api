import 'package:flutter/material.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/models/leaderboard_models.dart';
import '../../../core/app_theme.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../view_models/ranked_arena_view_model.dart';

class RankedArenaScreen extends StatelessWidget {
  final RankedArenaViewModel viewModel;
  final AuthViewModel authViewModel;

  const RankedArenaScreen({
    super.key,
    required this.viewModel,
    required this.authViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[viewModel, authViewModel]),
      builder: (BuildContext context, _) {
        final UserProfileModel? user = authViewModel.currentUser;
        if (user != null) {
          viewModel.syncAuthenticatedProfile(
            username: user.username,
            elo: user.currentElo,
            tier: user.currentTier,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'ARENA RANKED • ${viewModel.seasonId}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Actualizar Arena',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: viewModel.loadArenaData,
              ),
            ],
          ),
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: RefreshIndicator(
                      onRefresh: viewModel.loadArenaData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          if (viewModel.errorMessage != null)
                            _buildAlertBanner(
                              viewModel.errorMessage!,
                              ApexTheme.deloadCrimson,
                            ),
                          if (viewModel.statusBanner != null)
                            _buildAlertBanner(
                              viewModel.statusBanner!,
                              ApexTheme.readinessGreen,
                            ),
                          _buildTierProgressHeroCard(user),
                          const SizedBox(height: 14),
                          _buildMetricSelectorBar(),
                          const SizedBox(height: 14),
                          _buildMatchmakingActionsRow(context),
                          const SizedBox(height: 14),
                          if (viewModel.activeDuel != null)
                            _buildHeadToHeadDuelCard(viewModel.activeDuel!)
                          else
                            _buildNoActiveDuelCard(context),
                          const SizedBox(height: 18),
                          const Text(
                            'CLASIFICACIÓN GLOBAL NORMALIZADA (POSTGRESQL)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ApexTheme.textMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (viewModel.globalEntries.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'Aún no hay atletas clasificados en esta temporada.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: ApexTheme.textMuted),
                                ),
                              ),
                            )
                          else
                            ...viewModel.globalEntries.map(
                              (LeaderboardRowModel row) =>
                                  _buildLeaderboardRowCard(row, user?.username),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAlertBanner(String text, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTierProgressHeroCard(UserProfileModel? user) {
    final int remaining =
        (viewModel.nextTierTargetElo - viewModel.myElo).clamp(0, 2000);
    final String displayUsername = user?.username ?? viewModel.myUsername;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ApexTheme.cyanElectric.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ApexTheme.cyanElectric),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ApexTheme.cyanElectric,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'TIER ${viewModel.myTier.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: ApexTheme.textPrimary,
                        ),
                      ),
                      if (displayUsername.isNotEmpty)
                        Text(
                          '@$displayUsername',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ApexTheme.cyanElectric,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        'Bronce • Plata • Oro • Platino • Diamante • Élite',
                        style: TextStyle(
                          fontSize: 10,
                          color: ApexTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${viewModel.myElo} ELO',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: ApexTheme.voltAccent,
                      ),
                    ),
                    Text(
                      'Faltan $remaining pts para ${viewModel.nextTierName}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ApexTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: viewModel.tierProgressRatio,
                minHeight: 9,
                backgroundColor: ApexTheme.obsidianBg,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ApexTheme.voltAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSelectorBar() {
    final bool isLbm = viewModel.metricTarget == 'LBM_ALLOMETRIC_RATIO';
    return Row(
      children: <Widget>[
        Expanded(
          child: ChoiceChip(
            label: const Text('ÍNDICE ALOMÉTRICO (LBM^0.67)'),
            selected: isLbm,
            selectedColor: ApexTheme.voltAccent,
            labelStyle: TextStyle(
              color: isLbm ? Colors.black : ApexTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            onSelected: (_) =>
                viewModel.switchMetricTarget('LBM_ALLOMETRIC_RATIO'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: const Text('COEFICIENTE DOTS (IPF)'),
            selected: !isLbm,
            selectedColor: ApexTheme.cyanElectric,
            labelStyle: TextStyle(
              color: !isLbm ? Colors.black : ApexTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            onSelected: (_) =>
                viewModel.switchMetricTarget('DOTS_RELATIVE_VOLUME'),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchmakingActionsRow(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.cardGraphite,
              foregroundColor: ApexTheme.cyanElectric,
              side: const BorderSide(color: ApexTheme.cyanElectric),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: viewModel.isMatchmaking
                ? null
                : () => _openOpponentSearchModal(context),
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text(
              'RETAR POR USERNAME',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.voltAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: viewModel.isMatchmaking
                ? null
                : viewModel.startAutomaticMatchmaking,
            icon: viewModel.isMatchmaking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.radar_rounded, size: 18),
            label: const Text(
              'MATCHMAKING (±100 ELO)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveDuelCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ApexTheme.cardBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.sports_mma_outlined,
              color: ApexTheme.cyanElectric,
              size: 36,
            ),
            SizedBox(height: 8),
            Text(
              'SIN DUELO 1v1 ACTIVO ESTA SEMANA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Elige un rival registrado con "Retar por Username" o usa "Matchmaking (±100 ELO)" para competir en tiempo real con tus sesiones completadas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadToHeadDuelCard(HeadToHeadDuelModel duel) {
    final bool isLbm = viewModel.metricTarget == 'LBM_ALLOMETRIC_RATIO';
    final double myScore =
        isLbm ? duel.challengerLbmScore : duel.challengerDotsScore;
    final double oppScore =
        isLbm ? duel.opponentLbmScore : duel.opponentDotsScore;
    final double total = myScore + oppScore;
    final double myRatio =
        total > 0 ? (myScore / total).clamp(0.1, 0.9) : 0.5;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ApexTheme.cyanElectric, width: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'DUELO SEMANAL 1v1 • HEAD-TO-HEAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.cyanElectric,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ApexTheme.voltAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EN JUEGO: ±${duel.projectedEloStake} ELO',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.voltAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '@${duel.challengerUsername} (Tú)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${duel.challengerElo} ELO • ${duel.challengerTier}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ApexTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${myScore.toStringAsFixed(1)} pts • RPE ${duel.challengerRpeCompliancePct}%',
                        style: const TextStyle(
                          color: ApexTheme.voltAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: ApexTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '@${duel.opponentUsername}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${duel.opponentElo} ELO • ${duel.opponentTier}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ApexTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${oppScore.toStringAsFixed(1)} pts • RPE ${duel.opponentRpeCompliancePct}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: ApexTheme.cyanElectric,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: (myRatio * 100).round(),
                    child: Container(
                      height: 10,
                      color: ApexTheme.voltAccent,
                    ),
                  ),
                  Expanded(
                    flex: ((1.0 - myRatio) * 100).round(),
                    child: Container(
                      height: 10,
                      color: ApexTheme.cyanElectric,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardRowCard(
    LeaderboardRowModel row,
    String? currentUsername,
  ) {
    final bool isLbm = viewModel.metricTarget == 'LBM_ALLOMETRIC_RATIO';
    final double metricValue =
        isLbm ? row.lbmAllometricScore : row.dotsNormalizedVolume;
    final bool isMe = currentUsername != null &&
        row.username.toLowerCase() == currentUsername.toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isMe ? ApexTheme.voltAccent : ApexTheme.cardBorder,
          width: isMe ? 1.6 : 1.0,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isMe ? ApexTheme.voltAccent : ApexTheme.obsidianBg,
          foregroundColor: isMe ? Colors.black : ApexTheme.textPrimary,
          child: Text(
            '#${row.rank}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
        title: Text(
          isMe ? '@${row.username} (Tú)' : '@${row.username}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${row.tier} • Cumplimiento RPE: ${row.avgCompliancePct}% • Racha: 🔥${row.activeStreak}',
          style: const TextStyle(fontSize: 12, color: ApexTheme.textMuted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${row.currentElo} ELO',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: ApexTheme.voltAccent,
              ),
            ),
            Text(
              '${metricValue.toStringAsFixed(1)} pts',
              style: const TextStyle(
                fontSize: 11,
                color: ApexTheme.cyanElectric,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOpponentSearchModal(BuildContext context) {
    viewModel.searchOpponents('');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _OpponentSearchModalSheet(viewModel: viewModel);
      },
    );
  }
}

class _OpponentSearchModalSheet extends StatefulWidget {
  final RankedArenaViewModel viewModel;

  const _OpponentSearchModalSheet({
    required this.viewModel,
  });

  @override
  State<_OpponentSearchModalSheet> createState() =>
      _OpponentSearchModalSheetState();
}

class _OpponentSearchModalSheetState extends State<_OpponentSearchModalSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final List<OpponentSearchResultModel> results =
            widget.viewModel.searchResults;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'RETAR OPONENTE POR USERNAME (1v1 SEMANAL)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ApexTheme.cyanElectric,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar username registrado...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: ApexTheme.obsidianBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (String val) {
                  widget.viewModel.searchOpponents(val);
                },
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No se encontraron otros usuarios con ese username. Registra otro atleta o invita a un compañero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ApexTheme.textMuted, fontSize: 12),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (BuildContext ctx, int idx) {
                      final OpponentSearchResultModel opp = results[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: ApexTheme.obsidianBg,
                          child: Text(
                            opp.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: ApexTheme.voltAccent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          '@${opp.username}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${opp.tier} • ${opp.currentElo} ELO • Meta: ${opp.trainingGoal}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ApexTheme.textMuted,
                          ),
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ApexTheme.voltAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () async {
                            final bool ok = await widget.viewModel
                                .challengeByUsername(opp.username);
                            if (ok && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text(
                            'RETAR',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
