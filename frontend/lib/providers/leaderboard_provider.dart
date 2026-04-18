import 'package:flutter/material.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardService _service = LeaderboardService();

  LeaderboardResponse? _leaderboard;
  String? _error;
  bool _isLoading = false;

  LeaderboardResponse? get leaderboard => _leaderboard;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> fetchLeaderboard({int days = 30, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _leaderboard = await _service.getLeaderboard(days: days, limit: limit);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _leaderboard = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _leaderboard = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
