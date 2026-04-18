class LeaderboardEntry {
  final String userId;
  final String fullName;
  final int daysGoalMet;
  final int currentStreak;
  final int bestStreak;

  LeaderboardEntry({
    required this.userId,
    required this.fullName,
    required this.daysGoalMet,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      daysGoalMet: json['days_goal_met'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'days_goal_met': daysGoalMet,
        'current_streak': currentStreak,
        'best_streak': bestStreak,
      };
}

class LeaderboardResponse {
  final List<LeaderboardEntry> entries;
  final int total;

  LeaderboardResponse({
    required this.entries,
    required this.total,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return LeaderboardResponse(
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'total': total,
      };
}
