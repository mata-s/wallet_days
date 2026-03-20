import 'package:flutter/material.dart';
import 'package:saiyome/screens/budget_page.dart';
import 'package:saiyome/widgets/future_log_item.dart';
import 'package:saiyome/widgets/roast_card.dart';
import 'package:saiyome/widgets/summary_card.dart';
import 'package:saiyome/widgets/timeline_item.dart';
import 'package:saiyome/screens/add_expense_page.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/services/roast_service.dart';
import 'package:saiyome/services/expense_judge_service.dart';
import 'package:saiyome/services/remaining_budget_service.dart';
import 'package:saiyome/screens/timeline_page.dart';
import 'package:saiyome/screens/ranking_page.dart';
import 'package:saiyome/screens/rank_detail_page.dart';
import 'package:saiyome/services/rank_service.dart';
import 'package:saiyome/services/budget_history_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Expense> _expenses = [];
  BudgetSetting? _budgetSetting;
  RankResult? _rankResult;

  int _cycleOffsetMonths = 0;
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

Future<void> _loadInitialData() async {
  await _syncBudgetHistoryIfNeeded();

  await Future.wait([
    _loadExpenses(),
    _loadBudgetSetting(),
    _loadRankData(),
  ]);
}

Future<void> _syncBudgetHistoryIfNeeded() async {
  final budgetSetting = await IsarService.getBudgetSetting();
  if (budgetSetting == null) return;
  if (budgetSetting.totalBudget <= 0) return;

  await BudgetHistoryService.syncIfNeeded(
    cycleStartDay: budgetSetting.cycleStartDay,
    totalBudget: budgetSetting.totalBudget,
  );
}

  Future<void> _loadExpenses() async {
    final expenses = await IsarService.getExpenses();
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
    });
  }

  Future<void> _loadBudgetSetting() async {
    final budgetSetting = await IsarService.getBudgetSetting();
    if (!mounted) return;
    setState(() {
      _budgetSetting = budgetSetting;
    });
  }

  Future<void> _loadRankData() async {
  final histories = await IsarService.getBudgetHistories();
  if (!mounted) return;
  setState(() {
    _rankResult = RankService.calculate(histories);
  });
}

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'カフェ':
        return Icons.local_cafe_outlined;
      case 'コンビニ':
        return Icons.storefront_outlined;
      case '外食':
        return Icons.restaurant_outlined;
      case '日用品':
        return Icons.shopping_bag_outlined;
      case '趣味':
        return Icons.sports_esports_outlined;
      case '食費':
      default:
        return Icons.receipt_long_outlined;
    }
  }

  int get _usedAmount {
    return _currentCycleExpenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  int get _cycleStartDay {
    final day = _budgetSetting?.cycleStartDay ?? 1;
    return day.clamp(1, 28);
  }

DateTime get _currentCycleStart {
  final now = DateTime.now();
  return DateTime(now.year, now.month + _cycleOffsetMonths, _cycleStartDay);
}

DateTime get _currentCycleEnd {
  final start = _currentCycleStart;
  return DateTime(start.year, start.month + 1, _cycleStartDay);
}
  DateTime get _currentCycleEndExclusive {
    final start = _currentCycleStart;
    return DateTime(start.year, start.month + 1, _cycleStartDay);
  }

  List<Expense> get _currentCycleExpenses {
    final start = _currentCycleStart;
    final endExclusive = _currentCycleEndExclusive;

    return _expenses.where((expense) {
      final createdAt = expense.createdAt;
      return !createdAt.isBefore(start) && createdAt.isBefore(endExclusive);
    }).toList();
  }



  int get _totalBudget {
    return _budgetSetting?.totalBudget ?? 0;
  }

  int get _remainingBudget {
    final remaining = _totalBudget - _usedAmount;
    return remaining < 0 ? 0 : remaining;
  }

  int get _realWalletLifeDays {
    if (_cycleOffsetMonths != 0) return 0;
    if (_totalBudget <= 0) return 0;
    if (_remainingBudget <= 0) return 0;

    final cycleStart = _currentCycleStart;
    final cycleEnd = _currentCycleEnd;
    final totalCycleDays = cycleEnd.difference(cycleStart).inDays;
    if (totalCycleDays <= 0) return 0;

    final plannedDailyBudget = _totalBudget / totalCycleDays;
    if (plannedDailyBudget <= 0) return 0;

    return (_remainingBudget / plannedDailyBudget).ceil().clamp(1, 999);
  }

  int get _dailySpendingPaceYen {
    if (_cycleOffsetMonths != 0) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycleStart = _currentCycleStart;
    final normalizedCycleStart = DateTime(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day,
    );

    final elapsedDays = today.difference(normalizedCycleStart).inDays + 1;
    if (elapsedDays <= 0) return 0;
    if (_usedAmount <= 0) return 0;

    return (_usedAmount / elapsedDays).round();
  }

  int _remainingPeriodDays() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(
    _currentCycleEnd.year,
    _currentCycleEnd.month,
    _currentCycleEnd.day,
  );

  final diff = end.difference(today).inDays;
  return diff < 0 ? 0 : diff;
}

  int get _plannedDailyBudgetYen {
    if (_cycleOffsetMonths != 0) return 0;
    if (_totalBudget <= 0) return 0;

    final cycleStart = _currentCycleStart;
    final cycleEnd = _currentCycleEnd;
    final totalCycleDays = cycleEnd.difference(cycleStart).inDays;
    if (totalCycleDays <= 0) return 0;

    return (_totalBudget / totalCycleDays).round();
  }

  String _formatYen(int value) {
    final formatter = NumberFormat('#,###');
    return formatter.format(value);
  }

String _formatTimelineDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);

  final diff = today.difference(target).inDays;

  if (diff == 0) return '今日';
  if (diff == 1) return '昨日';

  return DateFormat('M/d').format(date);
}

String _formatCyclePeriod() {
  final start = _currentCycleStart;
  final end = _currentCycleEnd;
  return '${start.month}/${start.day} 〜 ${end.month}/${end.day}';
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
    alignment: Alignment.center,
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



  List<Map<String, dynamic>> get _categorySummaries {
    final categories = _budgetSetting?.categories ?? [];

    return categories.map((category) {
      final used = _currentCycleExpenses
          .where((expense) => expense.category == category.name)
          .fold<int>(0, (sum, expense) => sum + expense.amount);
      final remaining = category.budget - used;
      final usageRate = category.budget == 0 ? 0.0 : used / category.budget;

      return {
        'name': category.name,
        'badge': category.badge,
        'budget': category.budget,
        'used': used,
        'remaining': remaining,
        'usageRate': usageRate,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _dangerCategories {
    final summaries = _categorySummaries.where((category) {
      final budget = category['budget'] as int;
      if (budget == 0) return false;

      final usageRate = category['usageRate'] as double;
      final remaining = category['remaining'] as int;

      // danger if over budget OR usage >= 75%
      return remaining < 0 || usageRate >= 0.75;
    }).toList();

    summaries.sort((a, b) {
      final aRate = a['usageRate'] as double;
      final bRate = b['usageRate'] as double;
      return bRate.compareTo(aRate);
    });

    return summaries.take(3).toList();
  }

  int get _latestCategoryBudget {
    if (_currentCycleExpenses.isEmpty) return 0;

    final latestCategory = _currentCycleExpenses.first.category;
    final matchedCategory = _budgetSetting?.categories
        .where((category) => category.name == latestCategory)
        .toList();

    if (matchedCategory == null || matchedCategory.isEmpty) return 0;
    return matchedCategory.first.budget;
  }

  int get _latestCategoryUsed {
    if (_currentCycleExpenses.isEmpty) return 0;

    final latestCategory = _currentCycleExpenses.first.category;
    return _currentCycleExpenses
        .where((expense) => expense.category == latestCategory)
        .fold<int>(0, (sum, expense) => sum + expense.amount);
  }

    Map<ExpenseJudgeTag, int> get _latestCategoryTagUsedAmounts {
    if (_currentCycleExpenses.isEmpty) return {};

    final latestCategory = _currentCycleExpenses.first.category;
    final categoryExpenses = _currentCycleExpenses
        .where((expense) => expense.category == latestCategory)
        .toList();

    final totals = <ExpenseJudgeTag, int>{};

    for (final expense in categoryExpenses) {
      final judge = ExpenseJudgeService.judge(
        expense: expense,
        totalBudget: _totalBudget,
      );

      for (final tag in judge.tags) {
        totals[tag] = (totals[tag] ?? 0) + expense.amount;
      }
    }

    return totals;
  }

  RoastResult get _roastResult {
    return RoastService.build(
      totalBudget: _totalBudget,
      usedAmount: _usedAmount,
      expenses: _currentCycleExpenses,
      dangerCategories: _dangerCategories,
      latestCategoryBudget: _latestCategoryBudget,
      latestCategoryUsed: _latestCategoryUsed,
      cycleStart: _currentCycleStart,
      cycleEnd: _currentCycleEnd,
      latestCategoryTagUsedAmounts: _latestCategoryTagUsedAmounts,
    );
  }

    List<({String title, String message, String subMessage})> get _roastCards {
    final roast = _roastResult;

    final messages = roast.message
        .split('\n')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final subMessages = roast.subMessage
        .split('\n')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final count =
        messages.length > subMessages.length ? messages.length : subMessages.length;

    if (count <= 1) {
      return [
        (
          title: roast.title,
          message: roast.message,
          subMessage: roast.subMessage,
        ),
      ];
    }

    final cards = <({String title, String message, String subMessage})>[];
    for (var i = 0; i < count; i++) {
      cards.add(
        (
          title: i == 0 ? roast.title : '財布からもうひとこと',
          message: i < messages.length ? messages[i] : '',
          subMessage: i < subMessages.length ? subMessages[i] : '',
        ),
      );
    }

    return cards;
  }

  RemainingBudgetResult get _remainingBudgetResult {
    return RemainingBudgetService.build(
      totalBudget: _totalBudget,
      usedAmount: _usedAmount,
      cycleStart: _currentCycleStart,
      cycleEnd: _currentCycleEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('財布の余命'),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BudgetPage(),
                ),
              );

              if (result == true) {
                await _loadInitialData();
              }
            },
            icon: const Icon(Icons.savings_outlined),
            tooltip: '予算設定',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SummaryCard(
              remainingBudget: _remainingBudget,
              walletLifeDays: _realWalletLifeDays,
              remainingPeriodDays: _remainingPeriodDays(),
              totalBudget: _totalBudget,
              usedAmount: _usedAmount,
              remainingTitle: _remainingBudgetResult.title,
              remainingMessage: _remainingBudgetResult.message,
              remainingSubMessage: _remainingBudgetResult.subMessage,
              cyclePeriod: _formatCyclePeriod(),
              dailySpendingPaceYen: _dailySpendingPaceYen,
              plannedDailyBudgetYen: _plannedDailyBudgetYen,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RankDetailPage(
                      rankResult: _rankResult,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: Row(
                  children: [
                    _rankBadge(_rankResult?.rankKey, size: 52),
                    const SizedBox(width: 12),
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'やりくりランク',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.black45,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        _rankResult?.rankLabel ?? 'スターター',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: Text(
              '${_rankResult?.streak ?? 0}ヶ月連続で予算内',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
                  ],
                ),
              ),
            ),
            if (_dangerCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD7CC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠ 危険カテゴリ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_dangerCategories.isEmpty)
                    const Text('カテゴリ予算を設定すると、危険カテゴリがここに表示されます。')
                  else
                    ..._dangerCategories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(
                              category['badge'] as String,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category['name'] as String,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(builder: (_) {
                                    final remaining = category['remaining'] as int;
                                    final usageRate = category['usageRate'] as double;

                                    Color textColor;
                                    if (remaining < 0) {
                                      textColor = Colors.red;
                                    } else if (usageRate >= 0.9) {
                                      textColor = Colors.red;
                                    } else if (usageRate >= 0.75) {
                                      textColor = Colors.orange;
                                    } else {
                                      textColor = Colors.black87;
                                    }

                                    if (remaining < 0) {
                                      return Text(
                                        '予算オーバー ¥${_formatYen(remaining.abs())}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    }

                                    return Text(
                                      '残り ¥${_formatYen(remaining)} (${(usageRate * 100).round()}%)',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            Builder(builder: (_) {
                              final remaining = category['remaining'] as int;
                              final usageRate = category['usageRate'] as double;

                              Color color;

                              if (remaining < 0) {
                                color = Colors.red; // 予算オーバー
                              } else if (usageRate >= 0.9) {
                                color = Colors.red; // 危険
                              } else if (usageRate >= 0.75) {
                                color = Colors.orange; // 注意
                              } else {
                                color = Colors.grey;
                              }

                              return Icon(
                                Icons.warning_amber_rounded,
                                color: color,
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            ],
            const SizedBox(height: 16),
            ..._roastCards.expand((card) => [
                  RoastCard(
                    title: card.title,
                    message: card.message,
                    subMessage: card.subMessage,
                  ),
                  const SizedBox(height: 12),
                ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'カテゴリ別予算',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'カテゴリごとの進み方を確認できます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 164,
                    child: _categorySummaries.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: Text('カテゴリ予算を設定するとここに一覧が表示されます。'),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: Scrollbar(
                                  controller: _categoryScrollController,
                                  thumbVisibility: false,
                                  trackVisibility: false,
                                  radius: const Radius.circular(999),
                                  thickness: 4,
                                  scrollbarOrientation: ScrollbarOrientation.bottom,
                                  child: ListView.separated(
                                    controller: _categoryScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _categorySummaries.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final category = _categorySummaries[index];
                                      final budget = category['budget'] as int;
                                      final used = category['used'] as int;
                                      final progress = budget == 0
                                          ? 0.0
                                          : (used / budget).clamp(0.0, 1.0);

                                      return Container(
                                        width: 150,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFFEDEDED),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${category['badge']} ${category['name']}',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '予算 ¥${_formatYen(budget)}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Builder(builder: (_) {
                                              final remaining = category['remaining'] as int;
                                              final usageRate = category['usageRate'] as double;

                                              Color textColor;
                                              if (remaining < 0) {
                                                textColor = Colors.red;
                                              } else if (usageRate >= 0.9) {
                                                textColor = Colors.red;
                                              } else if (usageRate >= 0.75) {
                                                textColor = Colors.orange;
                                              } else {
                                                textColor = Colors.black87;
                                              }

                                              if (remaining < 0) {
                                                return Text(
                                                  '予算オーバー ¥${_formatYen(remaining.abs())}',
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                );
                                              }
                                              return Text(
                                                '残り ¥${_formatYen(remaining)}',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 8,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('${(progress * 100).round()}% 使用'),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFF0F0F0)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '分析',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '支出の傾向や振り返りを確認できます',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RankingPage(
                expenses: _expenses,
                formatYen: _formatYen,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.pie_chart_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '何に使っている？',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'カテゴリ別の支出ランキングを見る',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ],
  ),
),
            const SizedBox(height: 16),
           Text(
              'タイムライン',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_currentCycleExpenses.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('まだ支出がありません。最初の支出を追加してみましょう。'),
              ),
              const SizedBox(height: 90),
            ] else ...[
              ..._currentCycleExpenses.take(10).expand((expense) => [
                    TimelineItem(
                      title: expense.storeName,
                      subtitle: expense.category,
                      amount: '¥${_formatYen(expense.amount)}',
                      icon: _iconForCategory(expense.category),
                      date: _formatTimelineDate(expense.createdAt),
                    ),
                    if (expense.futureLogMessage != null) ...[
                      const SizedBox(height: 10),
                      FutureLogItem(message: expense.futureLogMessage!),
                    ],
                    const SizedBox(height: 10),
                  ]),
              if (_currentCycleExpenses.length > 10)
                Center(
                  child: TextButton(
                    onPressed: _openFullTimeline,
                    child: Text('もっと見る'),
                  ),
                ),
              const SizedBox(height:  70),
            ]
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddExpensePage(),
            ),
          );

          if (result == true) {
            await _loadInitialData();
          }
        },
        label: const Text('支出を追加'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _openFullTimeline() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimelinePage(
          expenses: _currentCycleExpenses,
          formatYen: _formatYen,
          categoryLabel: (category) => category,
          iconForCategory: _iconForCategory,
          formatTimelineDate: _formatTimelineDate,
        ),
      ),
    );
  }
}