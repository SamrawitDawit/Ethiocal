import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/leaderboard_card.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Consumer<LeaderboardProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load leaderboard',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          provider.fetchLeaderboard();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final leaderboard = provider.leaderboard;
              if (leaderboard == null || leaderboard.entries.isEmpty) {
                return Center(
                  child: Text(
                    'No leaderboard data available',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              // Get top 3 entries and rest
              final topThree = leaderboard.entries.take(3).toList();
              final restEntries = leaderboard.entries.skip(3).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const AppLogo(imageHeight: 28, fontSize: 18),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leaderboard',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Top 3 Podium
                            _buildTopThreePodium(topThree),
                            const SizedBox(height: 32),

                            // Rankings 4+
                            Text(
                              'Rankings',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: restEntries.length,
                              itemBuilder: (context, index) {
                                final entry = restEntries[index];
                                return LeaderboardCard(
                                  entry: entry,
                                  rank: index + 4,
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(List<LeaderboardEntry> topThree) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        children: [
          // Podium positions
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd Place (Left)
                if (topThree.length > 1)
                  Expanded(
                    child: _buildPodiumPosition(
                      entry: topThree[1],
                      rank: 2,
                      height: 120,
                    ),
                  ),
                const SizedBox(width: 8),

                // 1st Place (Center - Tallest)
                Expanded(
                  child: _buildPodiumPosition(
                    entry: topThree[0],
                    rank: 1,
                    height: 160,
                  ),
                ),
                const SizedBox(width: 8),

                // 3rd Place (Right)
                if (topThree.length > 2)
                  Expanded(
                    child: _buildPodiumPosition(
                      entry: topThree[2],
                      rank: 3,
                      height: 100,
                    ),
                  ),
              ],
            ),
          ),

          // Names and streaks below
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (topThree.length > 1) _buildPodiumName(topThree[1]),
              _buildPodiumName(topThree[0]),
              if (topThree.length > 2) _buildPodiumName(topThree[2]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition({
    required LeaderboardEntry entry,
    required int rank,
    required double height,
  }) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: colors[rank - 1].withOpacity(0.2),
                border: Border.all(
                  color: colors[rank - 1],
                  width: 2,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Positioned(
              top: -10,
              child: AvatarWidget(
                name: entry.fullName,
                radius: 28,
                backgroundColor: colors[rank - 1],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors[rank - 1].withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#$rank',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors[rank - 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumName(LeaderboardEntry entry) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(
            entry.fullName.split(' ')[0],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 12, color: Color(0xFFFF9800)),
              const SizedBox(width: 2),
              Text(
                '${entry.currentStreak}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
