import 'package:flutter/material.dart';
import 'package:saiyome/services/monthly_report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyReportPage extends StatefulWidget {
  final VoidCallback? onTapDetail;

  // 実データ取得用（指定があれば MonthlyReportService から取得）
  final DateTime periodStart;
  final DateTime periodEnd;

  const MonthlyReportPage({
    super.key,
    required this.periodStart,
    required this.periodEnd,
    this.onTapDetail,
  });

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();

  static String yen(int value) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    final text = abs.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '$sign$text円';
  }
}

class _MonthlyReportBundle {
  final Map<String, dynamic>? report;
  final Map<String, dynamic>? profile;

  const _MonthlyReportBundle({
    required this.report,
    required this.profile,
  });
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  Future<_MonthlyReportBundle>? _pageFuture;
  late DateTime _displayedPeriodStart;
  late DateTime _displayedPeriodEnd;

  @override
  void initState() {
    super.initState();
    _displayedPeriodStart = widget.periodStart;
    _displayedPeriodEnd = widget.periodEnd;
    _setupFuture();
  }

  @override
  void didUpdateWidget(covariant MonthlyReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodStart != widget.periodStart ||
        oldWidget.periodEnd != widget.periodEnd) {
      _displayedPeriodStart = widget.periodStart;
      _displayedPeriodEnd = widget.periodEnd;
      _setupFuture();
    }
  }

  void _setupFuture() {
    _pageFuture = _loadPageData(
      periodStart: _displayedPeriodStart,
      periodEnd: _displayedPeriodEnd,
    );
  }

  Future<_MonthlyReportBundle> _loadPageData({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final report = await MonthlyReportService.getReportForPeriod(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    Map<String, dynamic>? profile;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('current_title, current_title_reason, current_title_rarity')
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        profile = Map<String, dynamic>.from(response);
      }
    }

    return _MonthlyReportBundle(
      report: report,
      profile: profile,
    );
  }

  void _setDisplayedPeriod(DateTime start, DateTime end) {
    setState(() {
      _displayedPeriodStart = start;
      _displayedPeriodEnd = end;
      _setupFuture();
    });
  }

  void _goToPreviousPeriod() {
    final length =
        _displayedPeriodEnd.difference(_displayedPeriodStart).inDays + 1;
    final previousEnd =
        _displayedPeriodStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: length - 1));
    _setDisplayedPeriod(previousStart, previousEnd);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MonthlyReportBundle>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(context);
        }

        if (snapshot.hasError) {
          return _buildError(context, snapshot.error.toString());
        }

        final bundle = snapshot.data;
        final report = bundle?.report;
        final profile = bundle?.profile;
        if (report == null) {
          return _buildEmpty(context);
        }

        final totalBudget = (report['total_budget'] as num?)?.toInt() ?? 0;
        final currentTitle = ((profile?['current_title'] as String?) ?? '').trim();
        final currentTitleReason =
            ((profile?['current_title_reason'] as String?) ?? '').trim();
        final currentTitleRarity =
            ((profile?['current_title_rarity'] as String?) ?? 'common').trim();
        final totalSpent = (report['total_spent'] as num?)?.toInt() ?? 0;
        final remaining = (report['remaining_amount'] as num?)?.toInt() ?? 0;
        final achievementRate = totalBudget > 0
            ? (totalSpent / totalBudget).clamp(0, 1).toDouble()
            : 0.0;
        final summaryComment =
            (report['summary_text'] as String?)?.trim().isNotEmpty == true
                ? report['summary_text'] as String
                : 'まだ月のレポートがありません。';
        final adviceText = ((report['advice_text'] as String?) ?? '').trim();
        final badges = ((report['badges_json'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final rank = report['rank_json'] is Map
            ? Map<String, dynamic>.from(report['rank_json'] as Map)
            : <String, dynamic>{};

        return _buildContent(
          context,
          title: '月のレポート',
          periodText: _resolvedPeriodText(),
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          remaining: remaining,
          achievementRate: achievementRate,
          currentTitle: currentTitle,
          currentTitleReason: currentTitleReason,
          currentTitleRarity: currentTitleRarity,
          adviceText: adviceText,
          summaryComment: summaryComment,
          rank: rank,
          badges: badges,
        );
      },
    );
  }

  String _resolvedPeriodText() {
    return '${_displayedPeriodStart.month}/${_displayedPeriodStart.day} 〜 ${_displayedPeriodEnd.month}/${_displayedPeriodEnd.day}';
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月レポート'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EAE5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '月のレポートを読み込み中...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月レポート'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EAE5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '月のレポートを表示できませんでした',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月レポート'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EAE5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '月のレポート',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_resolvedPeriodText().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _resolvedPeriodText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _goToPreviousPeriod,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('前の期間'),
                    ),
                    if (_displayedPeriodStart != widget.periodStart ||
                        _displayedPeriodEnd != widget.periodEnd) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _setDisplayedPeriod(
                          widget.periodStart,
                          widget.periodEnd,
                        ),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('最新に戻る'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'この期間の月レポートはまだ作成されていません。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String title,
    required String periodText,
    required int totalBudget,
    required int totalSpent,
    required int remaining,
    required double achievementRate,
    required String currentTitle,
    required String currentTitleReason,
    required String currentTitleRarity,
    required String adviceText,
    required String summaryComment,
    required Map<String, dynamic> rank,
    required List<Map<String, dynamic>> badges,
  }) {
    final theme = Theme.of(context);
    final isOver = remaining < 0;
    final rankLabel = ((rank['rank_label'] as String?) ?? '').trim();
    final currentStreak = (rank['current_streak'] as num?)?.toInt() ?? 0;
    final bestStreak = (rank['best_streak'] as num?)?.toInt() ?? 0;
    final achievedCount = (rank['achieved_count'] as num?)?.toInt() ?? 0;
    final totalCount = (rank['total_count'] as num?)?.toInt() ?? 0;
    final hasTitle = currentTitle.isNotEmpty;
    final hasAdvice = adviceText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('月レポート'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EAE5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (periodText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              periodText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _goToPreviousPeriod,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('前の期間'),
                    ),
                    if (_displayedPeriodStart != widget.periodStart ||
                        _displayedPeriodEnd != widget.periodEnd) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _setDisplayedPeriod(
                          widget.periodStart,
                          widget.periodEnd,
                        ),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('最新に戻る'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (hasTitle) ...[
                  _TitleCard(
                    title: currentTitle,
                    reason: currentTitleReason,
                    rarity: currentTitleRarity,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: '予算',
                        value: MonthlyReportPage.yen(totalBudget),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: '支出',
                        value: MonthlyReportPage.yen(totalSpent),
                      ),
                    ),
                  ],
                ),
                if (rankLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RankCard(
                    rankLabel: rankLabel,
                    currentStreak: currentStreak,
                    bestStreak: bestStreak,
                    achievedCount: achievedCount,
                    totalCount: totalCount,
                  ),
                ],
                const SizedBox(height: 10),
                _RemainingCard(
                  remaining: remaining,
                  isOver: isOver,
                ),
                const SizedBox(height: 16),
                if (badges.isNotEmpty) ...[
                  Text(
                    '今月のバッヂ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: badges
                        .map(
                          (badge) => _BadgeChip(
                            title: (badge['title'] as String?)?.trim().isNotEmpty == true
                                ? badge['title'] as String
                                : 'バッヂ',
                            rarity: ((badge['rarity'] as String?) ?? 'common').trim(),
                            onTap: () {
                              final title = (badge['title'] as String?)?.trim().isNotEmpty == true
                                  ? badge['title'] as String
                                  : 'バッヂ';
                              final description = ((badge['description'] as String?) ?? '').trim();
                              final reason = ((badge['reason'] as String?) ?? '').trim();

                              showDialog<void>(
                                context: context,
                                builder: (dialogContext) {
                                  final dialogTheme = Theme.of(dialogContext);
                                  return AlertDialog(
                                    title: Text(title),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (description.isNotEmpty)
                                          Text(
                                            description,
                                            style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        if (description.isNotEmpty && reason.isNotEmpty)
                                          const SizedBox(height: 10),
                                        if (reason.isNotEmpty)
                                          Text(
                                            reason,
                                            style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                              height: 1.5,
                                            ),
                                          ),
                                        if (description.isEmpty && reason.isEmpty)
                                          Text(
                                            'このバッヂの詳細はまだありません。',
                                            style: dialogTheme.textTheme.bodyMedium,
                                          ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        child: const Text('閉じる'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF8F4),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '今月のまとめ',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (hasAdvice) ...[
        Text(
          adviceText,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.65,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(
        summaryComment,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.65,
        ),
      ),
    ],
  ),
),
                if (widget.onTapDetail != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: widget.onTapDetail,
                      child: const Text('月のレポートを見る'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  final int remaining;
  final bool isOver;

  const _RemainingCard({
    required this.remaining,
    required this.isOver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOver ? const Color(0xFFFFF0F0) : const Color(0xFFF3FBF4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOver ? '予算オーバー' : '残り予算',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            MonthlyReportPage.yen(remaining),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String title;
  final String rarity;
  final VoidCallback onTap;

  const _BadgeChip({
    required this.title,
    required this.rarity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (rarity.toLowerCase()) {
      case 'epic':
        backgroundColor = const Color(0xFFF4ECFF);
        textColor = const Color(0xFF7A4DCC);
        icon = Icons.auto_awesome;
        break;
      case 'rare':
        backgroundColor = const Color(0xFFEAF6FF);
        textColor = const Color(0xFF2E79B9);
        icon = Icons.stars_rounded;
        break;
      default:
        backgroundColor = const Color(0xFFF7F3EE);
        textColor = const Color(0xFF7A6254);
        icon = Icons.workspace_premium_outlined;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _RankCard extends StatelessWidget {
  final String rankLabel;
  final int currentStreak;
  final int bestStreak;
  final int achievedCount;
  final int totalCount;

  const _RankCard({
    required this.rankLabel,
    required this.currentStreak,
    required this.bestStreak,
    required this.achievedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_outlined, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '現在ランク：$rankLabel',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoChip(label: '達成', value: '$achievedCount/$totalCount回'),
              _MiniInfoChip(label: '連続', value: '${currentStreak}回'),
              _MiniInfoChip(label: '最高', value: '${bestStreak}回'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
class _TitleCard extends StatelessWidget {
  final String title;
  final String reason;
  final String rarity;

  const _TitleCard({
    required this.title,
    required this.reason,
    required this.rarity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color accentColor;
    IconData icon;

    switch (rarity.toLowerCase()) {
      case 'epic':
        backgroundColor = const Color(0xFFF4ECFF);
        accentColor = const Color(0xFF7A4DCC);
        icon = Icons.auto_awesome;
        break;
      case 'rare':
        backgroundColor = const Color(0xFFEAF6FF);
        accentColor = const Color(0xFF2E79B9);
        icon = Icons.stars_rounded;
        break;
      default:
        backgroundColor = const Color(0xFFF7F3EE);
        accentColor = const Color(0xFF7A6254);
        icon = Icons.workspace_premium_outlined;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今月の称号',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}