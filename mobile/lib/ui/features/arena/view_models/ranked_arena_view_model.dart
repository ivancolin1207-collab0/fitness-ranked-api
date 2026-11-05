import 'package:flutter/foundation.dart';
import '../../../../data/models/leaderboard_models.dart';
import '../../../../data/repositories/fitness_repository.dart';

class RankedArenaViewModel extends ChangeNotifier {
  final FitnessRepository _repository;

  RankedArenaViewModel({
    required FitnessRepository repository,
  }) : _repository = repository;

  String _seasonId = '2026-S4';
  String get seasonId => _seasonId;

  String _metricTarget = 'LBM_ALLOMETRIC_RATIO';
  String get metricTarget => _metricTarget;

  int _myElo = 1200;
  int get myElo => _myElo;

  String _myTier = 'Plata';
  String get myTier => _myTier;

  String _myUsername = '';
  String get myUsername => _myUsername;

  String get nextTierName {
    if (_myElo < 1100) return 'Plata';
    if (_myElo < 1300) return 'Oro';
    if (_myElo < 1500) return 'Platino';
    if (_myElo < 1700) return 'Diamante';
    if (_myElo < 1900) return 'Élite';
    return 'Élite Máximo';
  }

  int get nextTierTargetElo {
    if (_myElo < 1100) return 1100;
    if (_myElo < 1300) return 1300;
    if (_myElo < 1500) return 1500;
    if (_myElo < 1700) return 1700;
    if (_myElo < 1900) return 1900;
    return 2200;
  }

  double get tierProgressRatio {
    final int floorElo = (nextTierTargetElo - 200).clamp(900, 1900);
    return ((_myElo - floorElo) / 200.0).clamp(0.05, 1.0);
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isMatchmaking = false;
  bool get isMatchmaking => _isMatchmaking;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusBanner;
  String? get statusBanner => _statusBanner;

  List<LeaderboardRowModel> _globalEntries = <LeaderboardRowModel>[];
  List<LeaderboardRowModel> get globalEntries => _globalEntries;

  HeadToHeadDuelModel? _activeDuel;
  HeadToHeadDuelModel? get activeDuel => _activeDuel;

  List<SquadLeaderboardEntryModel> _squadsLeaderboard =
      <SquadLeaderboardEntryModel>[];
  List<SquadLeaderboardEntryModel> get squadsLeaderboard => _squadsLeaderboard;

  SquadLeaderboardEntryModel? get myActiveSquad {
    for (final SquadLeaderboardEntryModel s in _squadsLeaderboard) {
      if (s.isUserSquad) {
        return s;
      }
    }
    return _squadsLeaderboard.isNotEmpty ? _squadsLeaderboard.first : null;
  }

  List<OpponentSearchResultModel> _searchResults =
      <OpponentSearchResultModel>[];
  List<OpponentSearchResultModel> get searchResults => _searchResults;

  void syncAuthenticatedProfile({
    required String username,
    required int elo,
    required String tier,
  }) {
    _myUsername = username;
    _myElo = elo;
    _myTier = tier;
  }

  List<SquadLeaderboardEntryModel> _buildFallbackSquads() {
    final String me = _myUsername.isNotEmpty ? _myUsername : 'ivancolin230';
    return <SquadLeaderboardEntryModel>[
      SquadLeaderboardEntryModel(
        rank: 1,
        teamId: 'apex-squad-1',
        name: 'Apex Barbell Club',
        tag: 'APEX',
        memberCount: 4,
        totalLbmAllometricScore: 1560.9,
        totalDotsScore: 19180.0,
        avgConsistencyPct: 95.4,
        combinedSquadPoints: 1543.0,
        isUserSquad: true,
        members: <SquadMemberModel>[
          SquadMemberModel(
            username: me,
            role: 'CAPTAIN',
            weeklyLbmScore: 395.0,
            weeklyDotsScore: 4890.0,
            weeklyCompliancePct: 96.8,
          ),
          const SquadMemberModel(
            username: 'carlos_power',
            role: 'MEMBER',
            weeklyLbmScore: 412.5,
            weeklyDotsScore: 5180.0,
            weeklyCompliancePct: 96.5,
          ),
          const SquadMemberModel(
            username: 'diana_hybrid',
            role: 'MEMBER',
            weeklyLbmScore: 388.0,
            weeklyDotsScore: 4690.0,
            weeklyCompliancePct: 95.0,
          ),
          const SquadMemberModel(
            username: 'marco_str',
            role: 'MEMBER',
            weeklyLbmScore: 365.4,
            weeklyDotsScore: 4420.0,
            weeklyCompliancePct: 93.2,
          ),
        ],
      ),
      const SquadLeaderboardEntryModel(
        rank: 2,
        teamId: 'iron-squad-2',
        name: 'Iron Hypertrophy',
        tag: 'IRON',
        memberCount: 4,
        totalLbmAllometricScore: 1539.5,
        totalDotsScore: 18920.0,
        avgConsistencyPct: 92.9,
        combinedSquadPoints: 1512.1,
        isUserSquad: false,
        members: <SquadMemberModel>[
          SquadMemberModel(
            username: 'hector_lifts',
            role: 'CAPTAIN',
            weeklyLbmScore: 425.0,
            weeklyDotsScore: 5310.0,
            weeklyCompliancePct: 94.8,
          ),
          SquadMemberModel(
            username: 'sofia_fit',
            role: 'MEMBER',
            weeklyLbmScore: 392.0,
            weeklyDotsScore: 4810.0,
            weeklyCompliancePct: 93.5,
          ),
          SquadMemberModel(
            username: 'bruno_rpe9',
            role: 'MEMBER',
            weeklyLbmScore: 374.5,
            weeklyDotsScore: 4590.0,
            weeklyCompliancePct: 91.0,
          ),
          SquadMemberModel(
            username: 'valeria_gt',
            role: 'MEMBER',
            weeklyLbmScore: 348.0,
            weeklyDotsScore: 4210.0,
            weeklyCompliancePct: 92.4,
          ),
        ],
      ),
      const SquadLeaderboardEntryModel(
        rank: 3,
        teamId: 'titan-squad-3',
        name: 'Titan Endurance',
        tag: 'TITN',
        memberCount: 3,
        totalLbmAllometricScore: 1084.5,
        totalDotsScore: 13160.0,
        avgConsistencyPct: 93.2,
        combinedSquadPoints: 1066.0,
        isUserSquad: false,
        members: <SquadMemberModel>[
          SquadMemberModel(
            username: 'kyle_endure',
            role: 'CAPTAIN',
            weeklyLbmScore: 379.0,
            weeklyDotsScore: 4620.0,
            weeklyCompliancePct: 95.2,
          ),
          SquadMemberModel(
            username: 'elena_whoop',
            role: 'MEMBER',
            weeklyLbmScore: 361.5,
            weeklyDotsScore: 4390.0,
            weeklyCompliancePct: 94.0,
          ),
          SquadMemberModel(
            username: 'diego_barbell',
            role: 'MEMBER',
            weeklyLbmScore: 344.0,
            weeklyDotsScore: 4150.0,
            weeklyCompliancePct: 90.5,
          ),
        ],
      ),
    ];
  }

  Future<void> loadArenaData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
        _repository.loadLeaderboard(
          seasonId: _seasonId,
          metricTarget: _metricTarget,
        ),
        _repository.loadActiveDuel(seasonId: _seasonId),
        _repository
            .loadSquadsLeaderboard()
            .catchError((_) => _buildFallbackSquads()),
      ]);

      final LeaderboardResponseModel res =
          results[0] as LeaderboardResponseModel;
      final HeadToHeadDuelModel? duel = results[1] as HeadToHeadDuelModel?;
      final List<SquadLeaderboardEntryModel> squads =
          (results[2] as List<SquadLeaderboardEntryModel>?) ??
              _buildFallbackSquads();

      _seasonId = res.seasonId;
      _globalEntries = res.entries;
      _activeDuel = duel;
      _squadsLeaderboard = squads.isNotEmpty ? squads : _buildFallbackSquads();

      for (final LeaderboardRowModel row in _globalEntries) {
        if (_myUsername.isNotEmpty &&
            row.username.toLowerCase() == _myUsername.toLowerCase()) {
          _myElo = row.currentElo;
          _myTier = row.tier;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      if (_squadsLeaderboard.isEmpty) {
        _squadsLeaderboard = _buildFallbackSquads();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchMetricTarget(String target) async {
    if (_metricTarget == target) return;
    _metricTarget = target;
    await loadArenaData();
  }

  Future<void> searchOpponents(String query) async {
    try {
      _searchResults = await _repository.searchOpponentsByUsername(query);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      notifyListeners();
    }
  }

  Future<bool> challengeByUsername(String opponentUsername) async {
    _isMatchmaking = true;
    _errorMessage = null;
    _statusBanner = null;
    notifyListeners();

    try {
      _activeDuel = await _repository.challengeOpponentByUsername(
        opponentUsername: opponentUsername,
        metricTarget: _metricTarget,
        seasonId: _seasonId,
      );
      _statusBanner =
          'Duelo 1v1 iniciado contra @${_activeDuel!.opponentUsername} (en paralelo con tu Escuadra activa)';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isMatchmaking = false;
      notifyListeners();
    }
  }

  Future<void> startAutomaticMatchmaking() async {
    _isMatchmaking = true;
    _errorMessage = null;
    _statusBanner = null;
    notifyListeners();

    try {
      _activeDuel = await _repository.matchmakeAutomatic(
        metricTarget: _metricTarget,
        eloTolerance: 100,
        seasonId: _seasonId,
      );
      _statusBanner =
          'Matchmaking automático asignó a @${_activeDuel!.opponentUsername} (${_activeDuel!.opponentElo} ELO)';
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
    } finally {
      _isMatchmaking = false;
      notifyListeners();
    }
  }

  Future<bool> joinOrCreateSquad({
    required String squadName,
    required String squadTag,
  }) async {
    _isMatchmaking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<SquadLeaderboardEntryModel> updated =
          await _repository.joinOrCreateSquad(
        squadName: squadName,
        squadTag: squadTag,
      );
      _squadsLeaderboard = updated;
      _statusBanner =
          'Escuadra [$squadTag] $squadName activa. Tus entrenamientos suman simultáneamente al 1v1 y a tu Escuadra.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isMatchmaking = false;
      notifyListeners();
    }
  }
}
