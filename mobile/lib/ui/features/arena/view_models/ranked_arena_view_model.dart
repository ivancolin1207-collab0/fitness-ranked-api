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
      ]);

      final LeaderboardResponseModel res =
          results[0] as LeaderboardResponseModel;
      final HeadToHeadDuelModel? duel = results[1] as HeadToHeadDuelModel?;

      _seasonId = res.seasonId;
      _globalEntries = res.entries;
      _activeDuel = duel;

      for (final LeaderboardRowModel row in _globalEntries) {
        if (_myUsername.isNotEmpty &&
            row.username.toLowerCase() == _myUsername.toLowerCase()) {
          _myElo = row.currentElo;
          _myTier = row.tier;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
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
          'Duelo 1v1 iniciado contra @${_activeDuel!.opponentUsername}';
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
}
