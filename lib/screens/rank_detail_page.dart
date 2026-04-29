import 'package:flutter/material.dart';
import 'package:saiyome/services/rank_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? _languageOverride; // 'ja' or 'en'

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _languageOverride = prefs.getString('app_language');
    });
  }

  String _currentLang() {
    if (_languageOverride != null) return _languageOverride!;
    final device = Localizations.localeOf(context).languageCode;
    return device == 'ja' ? 'ja' : 'en';
  }

  String _t(String ja, String en) {
    return _currentLang() == 'ja' ? ja : en;
  }

  String _months(int value) {
    return _currentLang() == 'ja' ? '${value}ヶ月' : '$value mo.';
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
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
        return _t('ブロンズ', 'Bronze');
      case 'bronze':
        return _t('シルバー', 'Silver');
      case 'silver':
        return _t('ゴールド', 'Gold');
      case 'gold':
        return _t('プラチナ', 'Platinum');
      case 'platinum':
        return _t('ダイヤ', 'Diamond');
      default:
        return _t('最高ランク到達中', 'Top rank reached');
    }
  }

  String _nextRankHint(RankResult rank) {
    final achieved = rank.achievedCount;
    final rate = rank.successRate;
    final percent = (rate * 100).round();

switch (rank.rankKey) {
  case 'starter':
    return _t(
      'まずは今の期間を守れたら、ブロンズが見えてくるよ。',
      'Protect this period first, and Bronze will be within reach.',
    );

  case 'bronze':
    if (achieved < 2) {
      return _t(
        'あと${2 - achieved}ヶ月守れたら、シルバーにぐっと近づくよ。',
        '${2 - achieved} more good months, and Silver gets much closer.',
      );
    }
    if (rate < 0.50) {
      return _t(
        '今の達成率は$percent%。半分を超えたらシルバーだよ。',
        'Your success rate is $percent%. Pass 50%, and Silver is yours.',
      );
    }
    return _t(
      'シルバーまであと少し。財布も見守ってるよ。',
      'You are close to Silver. Your wallet is watching proudly.',
    );

  case 'silver':
    final needPeriods = achieved < 6 ? 6 - achieved : 0;
    if (needPeriods > 0) {
      return _t(
        'あと$needPeriodsヶ月守れたら、ゴールドの扉が開くよ。達成率70%以上も目指そう。',
        '$needPeriods more good months will open the door to Gold. Aim for a 70% success rate too.',
      );
    }
    if (rate < 0.70) {
      return _t(
        '今の達成率は$percent%。70%を超えたらゴールドだよ。',
        'Your success rate is $percent%. Reach 70%, and Gold is waiting.',
      );
    }
    return _t(
      'ゴールドまであと少し。かなりいい流れだよ。',
      'You are close to Gold. This is a really good flow.',
    );

  case 'gold':
    final needPeriods = achieved < 9 ? 9 - achieved : 0;
    if (needPeriods > 0) {
      return _t(
        'あと$needPeriodsヶ月積み上げたら、プラチナが見えてくるよ。達成率80%以上も意識しよう。',
        '$needPeriods more solid months, and Platinum starts to show. Aim for an 80% success rate too.',
      );
    }
    if (rate < 0.80) {
      return _t(
        '今の達成率は$percent%。80%を超えたらプラチナだよ。',
        'Your success rate is $percent%. Reach 80%, and Platinum is next.',
      );
    }
    return _t(
      'プラチナまであと少し。財布、かなり頼もしく見てるよ。',
      'You are close to Platinum. Your wallet is seriously impressed.',
    );

  case 'platinum':
    final needPeriods = achieved < 12 ? 12 - achieved : 0;
    if (needPeriods > 0) {
      return _t(
        'あと$needPeriodsヶ月守り切れたら、ダイヤが見えてくるよ。達成率90%以上も狙おう。',
        '$needPeriods more strong months, and Diamond comes into view. Aim for a 90% success rate too.',
      );
    }
    if (rate < 0.90) {
      return _t(
        '今の達成率は$percent%。90%を超えたらダイヤだよ。',
        'Your success rate is $percent%. Reach 90%, and Diamond is yours.',
      );
    }
    return _t(
      'ダイヤまであと少し。ここまで来たの、かなりすごいよ。',
      'You are close to Diamond. Getting this far is seriously impressive.',
    );

  default:
    return _t(
      '今は最高ランク。財布も拍手してるよ。この調子でいこう。',
      'You are at the top rank. Your wallet is cheering for you. Keep it going.',
    );
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

  String _localizedRankLabel(RankResult rank) {
    if (_currentLang() == 'ja') return rank.rankLabel;

    switch (rank.rankKey) {
      case 'diamond':
        return 'Diamond';
      case 'platinum':
        return 'Platinum';
      case 'gold':
        return 'Gold';
      case 'silver':
        return 'Silver';
      case 'bronze':
        return 'Bronze';
      default:
        return 'Starter';
    }
  }

  String _localizedRankComment(RankResult rank) {
    return _currentLang() == 'ja' ? rank.comment : rank.commentEn;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = widget.rankResult;
    final rankLabel = rank == null ? '' : _localizedRankLabel(rank);
    final rankComment = rank == null ? '' : _localizedRankComment(rank);
    final nextRankLabel = rank == null ? '' : _nextRankLabel(rank.rankKey);
    final nextRankHint = rank == null ? '' : _nextRankHint(rank);
    final nextRankProgress = rank == null ? 0.0 : _nextRankProgress(rank);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('ランク詳細', 'Rank details')),
        centerTitle: true,
      ),
      body: rank == null
          ? Center(child: Text(_t('データがありません', 'No data available')))
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
                        rankLabel,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t('現在のランク', 'Current rank'),
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
                        title: _t('連続達成', 'Current streak'),
                        value: _months(rank.streak),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: _t('最高連続', 'Best streak'),
                        value: _months(rank.bestStreak),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        title: _t('成功率', 'Success rate'),
                        value: '${(rank.successRate * 100).round()}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: _t('達成した月数', 'Successful months'),
                        value: _months(rank.achievedCount),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        title: _t('記録月数', 'Tracked months'),
                        value: _months(rank.totalCount),
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
                        _t('次のランクまで', 'Next rank progress'),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: Image.asset(
                          'assets/images/leeway.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('ひとこと', 'Note'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t('$rankComment', '$rankComment'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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