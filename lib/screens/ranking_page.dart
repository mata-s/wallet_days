import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/utils/time_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // int _selectedYear = DateTime.now().year;
  int _selectedYear = getNow().year;
  String? _languageOverride; // 'ja' or 'en'

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

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

  String _formatMoney(int amount) {
    if (_currentLang() == 'ja') {
      return '¥${widget.formatYen(amount)}';
    }

    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount / 100);
  }

  String _formatYear(int year) {
    return _currentLang() == 'ja' ? '$year年' : '$year';
  }

  List<Expense> get _filtered {
    // final now = DateTime.now();
    final now = getNow();

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
          ? _t('不明な支出先', 'Unknown store')
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
    // final now = DateTime.now();
    final now = getNow();

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
        return _t('この期間', 'This period');
      case _RangeType.all:
        return _t('これまで', 'All time');
      case _RangeType.lastMonth:
        return _t('先月', 'Last month');
      case _RangeType.yearly:
        return _t('年間別', 'Year');
    }
  }

  String _buildInsightComment(List<_StoreRankingItem> ranking, String compareText) {
    if (ranking.isEmpty) {
      return _t(
        'まだ支出が少ないから、使い方のクセはこれから見えてきそうだよ。',
        'There is not much spending data yet, so your patterns should become clearer over time.',
      );
    }

    final top = ranking.first;
    final topPercent = (top.ratio * 100).round();

    if (_range == _RangeType.lastMonth) {
      return _t(
        '先月は${top.category}がいちばん多くて、全体の$topPercent%だったよ。振り返るならまずここから見よう。',
        '${top.category} was your biggest spending area last month, making up $topPercent% of the total. Start here when reviewing your spending.',
      );
    }

    if (_range == _RangeType.yearly) {
      return _t(
        '${_selectedYear}年は${top.category}がいちばん多くて、全体の$topPercent%を占めているよ。年間で見るとクセが見えやすいね。',
        'In ${_formatYear(_selectedYear)}, ${top.category} is your biggest spending area at $topPercent% of the total. Yearly view makes patterns easier to spot.',
      );
    }

    if (compareText.isNotEmpty) {
      if (compareText.contains('+')) {
        return _t(
          '${top.category}が今のトップだよ。$compareText だから、最近少しペースが上がっているかも。',
          '${top.category} is currently your top spending area. $compareText, so your pace may be picking up a bit.',
        );
      }
      return _t(
        '${top.category}が今のトップだよ。$compareText だから、前より少し抑えられていていい流れだね。',
        '${top.category} is currently your top spending area. $compareText, so you are spending a little less than before. Nice flow.',
      );
    }

    if (_range == _RangeType.all) {
      return _t(
        'これまででいちばん多い支出先は${top.category}だったよ。全体の$topPercent%で、使い方のクセがはっきり出てるね。',
        '${top.category} is your biggest spending area so far, making up $topPercent% of the total. Your spending pattern is pretty clear here.',
      );
    }

    return _t(
      '${top.category}が今のトップで、全体の$topPercent%を占めているよ。まずはここを基準に振り返ると流れがつかみやすいね。',
      '${top.category} is currently on top at $topPercent% of your spending. Use this as the starting point for your review.',
    );
  }

  String _rankLabel(int index) {
    if (_currentLang() != 'ja') {
      switch (index) {
        case 0:
          return '1st';
        case 1:
          return '2nd';
        case 2:
          return '3rd';
        default:
          return '${index + 1}th';
      }
    }

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
            ? _t('先月より +${(compareRate * 100).round()}%', '+${(compareRate * 100).round()}% vs last month')
            : _t('先月より ${(compareRate * 100).round()}%', '${(compareRate * 100).round()}% vs last month');
    final insightComment = _buildInsightComment(ranking, compareText);

    return Scaffold(
      appBar: AppBar(title: Text(_t('何に使っている？', 'Where is it going?'))),
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
                            _formatYear(_selectedYear),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Image.asset(
                          'assets/images/usually.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.insights_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _t('ひとこと分析', 'Quick insight'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
                ? Center(child: Text(_t('データがありません', 'No data available')))
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
                                Text(_formatMoney(item.amount)),
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
                      child: Text(_t('キャンセル', 'Cancel'), style: const TextStyle(fontSize: 16)),
                    ),
                    Text(
                      _t('年を選択', 'Select year'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = years[tempIndex];
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        _t('決定', 'Done'),
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
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
                        _formatYear(year),
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