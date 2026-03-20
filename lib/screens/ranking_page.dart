import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:saiyome/models/expense.dart';

class RankingPage extends StatefulWidget {
  final List<Expense> expenses;
  final String Function(int) formatYen;

  const RankingPage({
    super.key,
    required this.expenses,
    required this.formatYen,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

enum _RangeType {
  current,
  all,
  lastMonth,
  yearly,
}

class _RankingPageState extends State<RankingPage> {
  _RangeType _range = _RangeType.current;
  int _selectedYear = DateTime.now().year;

  List<Expense> get _filtered {
    final now = DateTime.now();

    switch (_range) {
      case _RangeType.current:
        return widget.expenses;
      case _RangeType.all:
        return widget.expenses;
      case _RangeType.lastMonth:
        final firstDayThisMonth = DateTime(now.year, now.month, 1);
        final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayLastMonth = firstDayThisMonth.subtract(const Duration(days: 1));

        return widget.expenses.where((e) {
          return e.createdAt.isAfter(firstDayLastMonth.subtract(const Duration(days: 1))) &&
              e.createdAt.isBefore(lastDayLastMonth.add(const Duration(days: 1)));
        }).toList();
      case _RangeType.yearly:
        return widget.expenses.where((e) => e.createdAt.year == _selectedYear).toList();
    }
  }

  List<_StoreRankingItem> _buildRanking() {
    final Map<String, int> totals = {};

    for (final expense in _filtered) {
      final store = expense.storeName.trim().isEmpty
          ? '不明な支出先'
          : expense.storeName.trim();

      totals.update(
        store,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final items = totals.entries
        .map((entry) => _StoreRankingItem(category: entry.key, amount: entry.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final total = items.fold<int>(0, (sum, e) => sum + e.amount);

    return items
        .map((e) => e.copyWith(ratio: total == 0 ? 0 : e.amount / total))
        .toList();
  }

  double _compareWithLastMonth() {
    final now = DateTime.now();

    final firstDayThisMonth = DateTime(now.year, now.month, 1);
    final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayLastMonth = firstDayThisMonth.subtract(const Duration(days: 1));

    final lastMonthExpenses = widget.expenses.where((e) {
      return e.createdAt.isAfter(firstDayLastMonth.subtract(const Duration(days: 1))) &&
          e.createdAt.isBefore(lastDayLastMonth.add(const Duration(days: 1)));
    }).toList();

    final currentTotal = _filtered.fold<int>(0, (sum, e) => sum + e.amount);
    final lastTotal = lastMonthExpenses.fold<int>(0, (sum, e) => sum + e.amount);

    if (lastTotal == 0) return 0;

    return (currentTotal - lastTotal) / lastTotal;
  }

  String _label(_RangeType type) {
    switch (type) {
      case _RangeType.current:
        return 'この期間';
      case _RangeType.all:
        return 'これまで';
      case _RangeType.lastMonth:
        return '先月';
      case _RangeType.yearly:
        return '年間別';
    }
  }

  String _buildInsightComment(List<_StoreRankingItem> ranking, String compareText) {
    if (ranking.isEmpty) {
      return 'まだ支出が少ないので、使い方の傾向はこれから見えてきそうです。';
    }

    final top = ranking.first;
    final topPercent = (top.ratio * 100).round();

    if (_range == _RangeType.lastMonth) {
      return '${top.category}への支出が先月いちばん多く、全体の$topPercent%でした。先月の使い方を振り返る時にまず見たいポイントです。';
    }

    if (_range == _RangeType.yearly) {
      return '${_selectedYear}年は${top.category}への支出がいちばん多く、全体の$topPercent%を占めています。年間で見るとお金の使い方のクセがかなり見えやすいです。';
    }

    if (compareText.isNotEmpty) {
      if (compareText.contains('+')) {
        return '${top.category}への支出が現在トップです。$compareText なので、最近は少し使うペースが上がっているかもしれません。';
      }
      return '${top.category}への支出が現在トップです。$compareText なので、前より少し抑えられていていい流れです。';
    }

    if (_range == _RangeType.all) {
      return 'これまででいちばん多い支出先は${top.category}でした。全体の$topPercent%を占めていて、使い方の傾向がはっきり出ています。';
    }

    return '${top.category}への支出が現在トップで、全体の$topPercent%を占めています。まずはこの支出先を基準に振り返ると流れがつかみやすいです。';
  }

  String _rankLabel(int index) {
    switch (index) {
      case 0:
        return '1位';
      case 1:
        return '2位';
      case 2:
        return '3位';
      default:
        return '${index + 1}位';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranking = _buildRanking();
    final compareRate = _compareWithLastMonth();
    final compareText = compareRate == 0
        ? ''
        : compareRate > 0
            ? '先月より +${(compareRate * 100).round()}%'
            : '先月より ${(compareRate * 100).round()}%';
    final insightComment = _buildInsightComment(ranking, compareText);

    return Scaffold(
      appBar: AppBar(title: const Text('何に使っている？')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RangeType.current,
                      _RangeType.all,
                      _RangeType.lastMonth,
                      _RangeType.yearly,
                    ].map((type) {
                      final selected = _range == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(type)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _range = type;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_range == _RangeType.yearly)
                  GestureDetector(
                    onTap: _showYearPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedYear年',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'ひとこと分析',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (compareText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      compareText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    insightComment,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ranking.isEmpty
                ? const Center(child: Text('データがありません'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(ranking.length, (index) {
                      final item = ranking[index];
                      final percent = (item.ratio * 100).round();
                      final isTop3 = index < 3;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isTop3 ? const Color(0xFFFFF7E0) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isTop3
                              ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _rankLabel(index),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: index == 0
                                        ? Colors.orange
                                        : index == 1
                                            ? Colors.grey
                                            : index == 2
                                                ? Colors.brown
                                                : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.category,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text('¥${widget.formatYen(item.amount)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: item.ratio),
                            const SizedBox(height: 4),
                            Text('$percent%'),
                          ],
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  void _showYearPicker() {
    FocusScope.of(context).requestFocus(FocusNode());

    final years = widget.expenses
        .map((e) => e.createdAt.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int tempIndex = years.indexOf(_selectedYear);
    if (tempIndex < 0) tempIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                    ),
                    const Text(
                      '年を選択',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = years[tempIndex];
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        '決定',
                        style: TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: years.map((year) {
                    return Center(
                      child: Text(
                        '$year年',
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StoreRankingItem {
  final String category;
  final int amount;
  final double ratio;

  const _StoreRankingItem({
    required this.category,
    required this.amount,
    this.ratio = 0,
  });

  _StoreRankingItem copyWith({
    String? category,
    int? amount,
    double? ratio,
  }) {
    return _StoreRankingItem(
      category: category ?? this.category,
      amount: amount ?? this.amount,
      ratio: ratio ?? this.ratio,
    );
  }
}