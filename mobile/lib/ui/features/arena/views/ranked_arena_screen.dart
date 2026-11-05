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
            toolbarHeight: kToolbarHeight,
            titleSpacing: 12,
            title: Text(
              'ARENA RANKED • ${viewModel.seasonId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Crear / Cambiar Escuadra',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(
                        Icons.groups_2_outlined,
                        color: ApexTheme.voltAccent,
                        size: 20,
                      ),
                      onPressed: () => _openSquadModal(context),
                    ),
                    IconButton(
                      tooltip: 'Actualizar Arena',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: viewModel.loadArenaData,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.loadArenaData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            const SizedBox(height: 10),
                            _buildMetricSelectorBar(),
                            const SizedBox(height: 10),
                            _buildMatchmakingActionsRow(context),
                            const SizedBox(height: 10),
                            // 1. Duelo Semanal 1v1 Activo
                            if (viewModel.activeDuel != null)
                              _buildHeadToHeadDuelCard(viewModel.activeDuel!)
                            else
                              _buildNoActiveDuelCard(context),
                            const SizedBox(height: 14),
                            // 2. Duelo Simultáneo de Escuadras / Grupal (3 a 5 atletas)
                            _buildSquadsSimultaneousSection(context),
                            const SizedBox(height: 14),
                            const Text(
                              'CLASIFICACIÓN GLOBAL NORMALIZADA (POSTGRESQL)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ApexTheme.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (viewModel.globalEntries.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Aún no hay atletas clasificados en esta temporada.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: ApexTheme.textMuted),
                                  ),
                                ),
                              )
                            else
                              ...viewModel.globalEntries.map(
                                (LeaderboardRowModel row) =>
                                    _buildLeaderboardRowCard(
                                  row,
                                  user?.username,
                                ),
                              ),
                          ],
                        ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: ApexTheme.cyanElectric.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ApexTheme.cyanElectric),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ApexTheme.cyanElectric,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'TIER ${viewModel.myTier.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: ApexTheme.textPrimary,
                        ),
                      ),
                      if (displayUsername.isNotEmpty)
                        Text(
                          '@$displayUsername',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ApexTheme.cyanElectric,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        '1v1 Individual + Escuadra (3–5 atletas) Simultáneos',
                        style: TextStyle(
                          fontSize: 9.5,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ApexTheme.voltAccent,
                      ),
                    ),
                    Text(
                      'Faltan $remaining pts para ${viewModel.nextTierName}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ApexTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: viewModel.tierProgressRatio,
                minHeight: 8,
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
      spacing: 8,
      children: <Widget>[
        Expanded(
          child: ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: const Text(
              'ÍNDICE ALOMÉTRICO (LBM^0.67)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isLbm,
            selectedColor: ApexTheme.voltAccent,
            labelStyle: TextStyle(
              color: isLbm ? Colors.black : ApexTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
            onSelected: (_) =>
                viewModel.switchMetricTarget('LBM_ALLOMETRIC_RATIO'),
          ),
        ),
        Expanded(
          child: ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: const Text(
              'COEFICIENTE DOTS (IPF)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: !isLbm,
            selectedColor: ApexTheme.cyanElectric,
            labelStyle: TextStyle(
              color: !isLbm ? Colors.black : ApexTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
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
      spacing: 8,
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.cardGraphite,
              foregroundColor: ApexTheme.cyanElectric,
              side: const BorderSide(color: ApexTheme.cyanElectric),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onPressed: viewModel.isMatchmaking
                ? null
                : () => _openOpponentSearchModal(context),
            icon: const Icon(Icons.person_search_rounded, size: 17),
            label: const Text(
              'RETAR POR USERNAME',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.voltAccent,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onPressed: viewModel.isMatchmaking
                ? null
                : viewModel.startAutomaticMatchmaking,
            icon: viewModel.isMatchmaking
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.radar_rounded, size: 17),
            label: const Text(
              'MATCHMAKING (±100 ELO)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.cardBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.sports_mma_outlined,
              color: ApexTheme.cyanElectric,
              size: 32,
            ),
            SizedBox(height: 6),
            Text(
              'SIN DUELO 1v1 ACTIVO ESTA SEMANA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Elige un rival con "Retar por Username" (ej. @Alan) o "Matchmaking (±100 ELO)". Tus entrenos sumarán en paralelo tanto al 1v1 como a tu Escuadra.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.cyanElectric, width: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '1. DUELO SEMANAL 1v1 ACTIVO • HEAD-TO-HEAD',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.cyanElectric,
                      letterSpacing: 0.4,
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
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '@${duel.challengerUsername} (Tú)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
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
                          fontSize: 11.5,
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
                      fontSize: 14,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
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
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: (myRatio * 100).round(),
                    child: Container(
                      height: 9,
                      color: ApexTheme.voltAccent,
                    ),
                  ),
                  Expanded(
                    flex: ((1.0 - myRatio) * 100).round(),
                    child: Container(
                      height: 9,
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

  /// Sección 2: Duelo de Escuadras / Grupal (Squads Leaderboard 3 a 5 atletas)
  /// Corriendo simultáneamente con el Duelo 1v1.
  Widget _buildSquadsSimultaneousSection(BuildContext context) {
    final List<SquadLeaderboardEntryModel> squads =
        viewModel.squadsLeaderboard;
    final bool isLbm = viewModel.metricTarget == 'LBM_ALLOMETRIC_RATIO';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ApexTheme.voltAccent.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.groups_rounded,
                  color: ApexTheme.voltAccent,
                  size: 18,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '2. DUELO DE ESCUADRAS • SQUADS LEADERBOARD (3–5 ATLETAS)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: ApexTheme.voltAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Corre en simultáneo con tu 1v1 • Suma Σ(LBM^0.67) + Consistencia Semanal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: ApexTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _openSquadModal(context),
                  icon: const Icon(
                    Icons.add_moderator_outlined,
                    size: 14,
                    color: ApexTheme.cyanElectric,
                  ),
                  label: const Text(
                    'Mi Escuadra',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ApexTheme.cyanElectric,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...squads.map((SquadLeaderboardEntryModel squad) {
              final double displayTotal = isLbm
                  ? squad.totalLbmAllometricScore
                  : squad.totalDotsScore;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ApexTheme.obsidianBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: squad.isUserSquad
                        ? ApexTheme.voltAccent
                        : ApexTheme.cardBorder,
                    width: squad.isUserSquad ? 1.4 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: squad.isUserSquad
                              ? ApexTheme.voltAccent
                              : ApexTheme.cardGraphite,
                          foregroundColor: squad.isUserSquad
                              ? Colors.black
                              : ApexTheme.textPrimary,
                          child: Text(
                            '#${squad.rank}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '[${squad.tag}] ${squad.name}${squad.isUserSquad ? " • TU ESCUADRA" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  color: squad.isUserSquad
                                      ? ApexTheme.voltAccent
                                      : ApexTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${squad.memberCount} atletas activos • Consistencia media: ${squad.avgConsistencyPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ApexTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '${squad.combinedSquadPoints.toStringAsFixed(0)} PTS',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: ApexTheme.cyanElectric,
                              ),
                            ),
                            Text(
                              'Σ ${isLbm ? "LBM^0.67" : "DOTS"}: ${displayTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: ApexTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: squad.members.map((SquadMemberModel m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ApexTheme.cardGraphite,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '@${m.username} (${m.weeklyLbmScore.toStringAsFixed(0)})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ApexTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isMe ? ApexTheme.voltAccent : ApexTheme.cardBorder,
            width: isMe ? 1.5 : 1.0,
          ),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 17,
            backgroundColor:
                isMe ? ApexTheme.voltAccent : ApexTheme.obsidianBg,
            foregroundColor: isMe ? Colors.black : ApexTheme.textPrimary,
            child: Text(
              '#${row.rank}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          title: Text(
            isMe ? '@${row.username} (Tú)' : '@${row.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          subtitle: Text(
            '${row.tier} • Cumplimiento RPE: ${row.avgCompliancePct}% • Racha: 🔥${row.activeStreak}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${row.currentElo} ELO',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
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

  void _openSquadModal(BuildContext context) {
    final TextEditingController nameCtrl = TextEditingController(
      text: viewModel.myActiveSquad?.name ?? 'Apex Barbell Club',
    );
    final TextEditingController tagCtrl = TextEditingController(
      text: viewModel.myActiveSquad?.tag ?? 'APEX',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'UNIRSE O CREAR ESCUADRA (3 A 5 ATLETAS)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ApexTheme.voltAccent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu Escuadra suma tus puntos LBM^0.67 y consistencia semanal sin sobreescribir tu Duelo 1v1 individual.',
                style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                spacing: 8,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Escuadra',
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(
                        labelText: 'TAG',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () async {
                  final bool ok = await viewModel.joinOrCreateSquad(
                    squadName: nameCtrl.text.trim(),
                    squadTag: tagCtrl.text.trim(),
                  );
                  if (ok && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                icon: const Icon(Icons.groups_rounded),
                label: const Text(
                  'ACTIVAR ESCUADRA SIMULTÁNEA',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
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
            top: 18,
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
                  labelText: 'Buscar username registrado (ej. Alan)...',
                  isDense: true,
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
                  padding: EdgeInsets.symmetric(vertical: 16),
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
                    physics: const BouncingScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (BuildContext ctx, int idx) {
                      final OpponentSearchResultModel opp = results[idx];
                      final String initial = opp.username.isNotEmpty
                          ? opp.username.substring(0, 1).toUpperCase()
                          : 'A';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: ApexTheme.obsidianBg,
                          child: Text(
                            initial,
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
                            fontSize: 11.5,
                            color: ApexTheme.textMuted,
                          ),
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ApexTheme.voltAccent,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
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
                              fontSize: 11.5,
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
