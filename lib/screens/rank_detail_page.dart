import 'package:flutter/material.dart';
import 'package:saiyome/services/rank_service.dart';

class RankDetailPage extends StatefulWidget {
  final RankResult? rankResult;

  const RankDetailPage({
    super.key,
    required this.rankResult,
  });

  @override
  State<RankDetailPage> createState() => _RankDetailPageState();
}

class _RankDetailPageState extends State<RankDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 0.97)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.97, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_badgeController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _badgeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  Widget _rankBadge(String? rankKey, {double size = 52}) {
    Color color;

    switch (rankKey) {
      case 'diamond':
        color = const Color(0xFF8B5CF6);
        break;
      case 'platinum':
        color = const Color(0xFF94A3B8);
        break;
      case 'gold':
        color = const Color(0xFFF5B700);
        break;
      case 'silver':
        color = const Color(0xFFB8C2CC);
        break;
      case 'bronze':
        color = const Color(0xFFC47A44);
        break;
      default:
        color = const Color(0xFFA3A3A3);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_graph_rounded,
        color: Colors.white,
        size: size * 0.42,
      ),
    );
  }

  String _nextRankLabel(String rankKey) {
    switch (rankKey) {
      case 'starter':
        return 'ブロンズ';
      case 'bronze':
        return 'シルバー';
      case 'silver':
        return 'ゴールド';
      case 'gold':
        return 'プラチナ';
      case 'platinum':
        return 'ダイヤ';
      default:
        return '最高ランク到達中';
    }
  }

  String _nextRankHint(RankResult rank) {
    final achieved = rank.achievedCount;
    final rate = rank.successRate;
    final percent = (rate * 100).round();

    switch (rank.rankKey) {
      case 'starter':
        return 'まずは今の期間を達成するとブロンズになります。';
      case 'bronze':
        if (achieved < 2) {
          return 'あと${2 - achieved}ヶ月達成すると、シルバー条件に近づきます。';
        }
        if (rate < 0.50) {
          return '達成率は今$percent%です。50%以上でシルバーです。';
        }
        return 'シルバー条件まであと少しです。';
      case 'silver':
        final needPeriods = achieved < 6 ? 6 - achieved : 0;
        if (needPeriods > 0) {
          return 'あと$needPeriodsヶ月達成して、達成率70%以上でゴールドです。';
        }
        if (rate < 0.70) {
          return '達成率は今$percent%です。70%以上でゴールドです。';
        }
        return 'ゴールド条件まであと少しです。';
      case 'gold':
        final needPeriods = achieved < 9 ? 9 - achieved : 0;
        if (needPeriods > 0) {
          return 'あと$needPeriodsヶ月達成して、達成率80%以上でプラチナです。';
        }
        if (rate < 0.80) {
          return '達成率は今$percent%です。80%以上でプラチナです。';
        }
        return 'プラチナ条件まであと少しです。';
      case 'platinum':
        final needPeriods = achieved < 12 ? 12 - achieved : 0;
        if (needPeriods > 0) {
          return 'あと$needPeriodsヶ月達成して、達成率90%以上でダイヤです。';
        }
        if (rate < 0.90) {
          return '達成率は今$percent%です。90%以上でダイヤです。';
        }
        return 'ダイヤ条件まであと少しです。';
      default:
        return '現在最高ランクです。この調子で維持していきましょう。';
    }
  }

  double _nextRankProgress(RankResult rank) {
    final achieved = rank.achievedCount.toDouble();
    final rate = rank.successRate;

    switch (rank.rankKey) {
      case 'starter':
        return rank.achievedCount >= 1 ? 1.0 : 0.0;
      case 'bronze':
        final progressByCount = (achieved / 2).clamp(0.0, 1.0);
        final progressByRate = (rate / 0.50).clamp(0.0, 1.0);
        return ((progressByCount + progressByRate) / 2).clamp(0.0, 1.0);
      case 'silver':
        final progressByCount = (achieved / 6).clamp(0.0, 1.0);
        final progressByRate = (rate / 0.70).clamp(0.0, 1.0);
        return ((progressByCount + progressByRate) / 2).clamp(0.0, 1.0);
      case 'gold':
        final progressByCount = (achieved / 9).clamp(0.0, 1.0);
        final progressByRate = (rate / 0.80).clamp(0.0, 1.0);
        return ((progressByCount + progressByRate) / 2).clamp(0.0, 1.0);
      case 'platinum':
        final progressByCount = (achieved / 12).clamp(0.0, 1.0);
        final progressByRate = (rate / 0.90).clamp(0.0, 1.0);
        return ((progressByCount + progressByRate) / 2).clamp(0.0, 1.0);
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = widget.rankResult;
    final nextRankLabel = rank == null ? '' : _nextRankLabel(rank.rankKey);
    final nextRankHint = rank == null ? '' : _nextRankHint(rank);
    final nextRankProgress = rank == null ? 0.0 : _nextRankProgress(rank);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ランク詳細'),
        centerTitle: true,
      ),
      body: rank == null
          ? const Center(child: Text('データがありません'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                /// ランク表示
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _badgeScale,
                        child: _rankBadge(rank.rankKey, size: 64),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rank.rankLabel,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '現在のランク',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// ステータス
                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        title: '連続達成',
                        value: '${rank.streak}ヶ月',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: '最高連続',
                        value: '${rank.bestStreak}ヶ月',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        title: '成功率',
                        value: '${(rank.successRate * 100).round()}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: '達成した月数',
                        value: '${rank.achievedCount}ヶ月',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: '記録月数',
                        value: '${rank.totalCount}ヶ月',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '次のランクまで',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextRankLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: nextRankProgress,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        nextRankHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// コメント
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3E3CD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ひとこと',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rank.comment,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}