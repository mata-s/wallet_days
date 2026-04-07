import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';

class MoneyUsagePage extends StatefulWidget {
  const MoneyUsagePage({super.key});

  @override
  State<MoneyUsagePage> createState() => _MoneyUsagePageState();
}

enum _UsagePeriod {
  thisMonth,
  lastMonth,
  byYear,
  all,
}

class _MoneyUsagePageState extends State<MoneyUsagePage> {
  final NumberFormat _yenFormatter = NumberFormat('#,###');

  bool _isLoading = true;
  List<Expense> _expenses = [];
  List<BudgetHistory> _budgetHistories = [];
  _UsagePeriod _selectedPeriod = _UsagePeriod.thisMonth;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    final expenses = await IsarService.getExpenses();
    final budgetHistories = await IsarService.getBudgetHistories();
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;

    setState(() {
      _expenses = expenses;
      _budgetHistories = budgetHistories;
      _isLoading = false;
    });
  }


List<BudgetHistory> get _sortedBudgetHistories {
  final list = [..._budgetHistories];
  list.sort((a, b) => b.endDate.compareTo(a.endDate));
  return list;
}

BudgetHistory? get _currentHistory {
  final now = DateTime.now();
  for (final history in _sortedBudgetHistories) {
    final isInRange =
        !now.isBefore(history.startDate) && !now.isAfter(history.endDate);
    if (isInRange) return history;
  }
  return _sortedBudgetHistories.isEmpty ? null : _sortedBudgetHistories.first;
}

List<BudgetHistory> get _relevantBudgetHistories {
  final sorted = _sortedBudgetHistories;

  switch (_selectedPeriod) {
    case _UsagePeriod.thisMonth:
      final current = _currentHistory;
      return current == null ? [] : [current];

    case _UsagePeriod.lastMonth:
      final current = _currentHistory;
      if (current == null) return [];
      final index = sorted.indexWhere((h) => h.id == current.id);
      if (index < 0 || index + 1 >= sorted.length) return [];
      return [sorted[index + 1]];

    case _UsagePeriod.byYear:
      return sorted.where((history) {
        return history.startDate.year == _selectedYear ||
            history.endDate.year == _selectedYear;
      }).toList();

    case _UsagePeriod.all:
      return sorted;
  }
}

List<Expense> get _filteredExpenses {
  final histories = _relevantBudgetHistories;
  if (histories.isEmpty) return [];

  return _expenses.where((expense) {
    for (final history in histories) {
      final isInRange =
          !expense.createdAt.isBefore(history.startDate) &&
          !expense.createdAt.isAfter(history.endDate);
      if (isInRange) return true;
    }
    return false;
  }).toList();
}

  int get _totalAmount =>
      _filteredExpenses.fold<int>(0, (sum, e) => sum + e.amount);

  int get _allTimeTotal =>
      _expenses.fold<int>(0, (sum, e) => sum + e.amount.toInt());



int get _remainingBudget {
  final histories = _relevantBudgetHistories;
  if (histories.isEmpty) return 0;

  final totalBudget = histories.fold<int>(
    0,
    (sum, history) => sum + history.totalBudget,
  );

  return totalBudget - _totalAmount;
}

int get _previousPeriodTotal {
  final sorted = _sortedBudgetHistories;
  final current = _currentHistory;
  if (sorted.isEmpty || current == null) return 0;

  switch (_selectedPeriod) {
    case _UsagePeriod.thisMonth:
      final index = sorted.indexWhere((h) => h.id == current.id);
      if (index < 0 || index + 1 >= sorted.length) return 0;
      return sorted[index + 1].totalExpense;

    case _UsagePeriod.lastMonth:
      final index = sorted.indexWhere((h) => h.id == current.id);
      if (index < 0 || index + 2 >= sorted.length) return 0;
      return sorted[index + 2].totalExpense;

    case _UsagePeriod.byYear:
      return sorted
          .where((history) =>
              history.startDate.year == _selectedYear - 1 ||
              history.endDate.year == _selectedYear - 1)
          .fold<int>(0, (sum, history) => sum + history.totalExpense);

    case _UsagePeriod.all:
      return 0;
  }
}

  String get _selectedPeriodLabel {
    switch (_selectedPeriod) {
      case _UsagePeriod.thisMonth:
        return '今月';
      case _UsagePeriod.lastMonth:
        return '先月';
      case _UsagePeriod.byYear:
        return '$_selectedYear年';
      case _UsagePeriod.all:
        return '全期間';
    }
  }

  String get _comparisonLabel {
    switch (_selectedPeriod) {
      case _UsagePeriod.thisMonth:
        return '先月比';
      case _UsagePeriod.lastMonth:
        return '前月比';
      case _UsagePeriod.byYear:
        return '前年比';
      case _UsagePeriod.all:
        return '';
    }
  }

  List<_AmountRow> get _categoryTotals {
    final map = <String, int>{};

    for (final expense in _filteredExpenses) {
      map[expense.category] =
          (map[expense.category] ?? 0) + expense.amount.toInt();
    }

    final rows = map.entries
        .map((entry) => _AmountRow(label: entry.key, amount: entry.value))
        .toList();

    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  List<_AmountRow> get _storeTotals {
    final map = <String, int>{};

    for (final expense in _filteredExpenses) {
      final label = expense.storeName.trim().isEmpty ? '店名なし' : expense.storeName;
      map[label] = (map[label] ?? 0) + expense.amount.toInt();
    }

    final rows = map.entries
        .map((entry) => _AmountRow(label: entry.key, amount: entry.value))
        .toList();

    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows.take(10).toList();
  }

List<int> get _availableYears {
  final years = _budgetHistories
      .expand((history) => [history.startDate.year, history.endDate.year])
      .toSet()
      .toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}

  void _showYearPicker() {
    FocusScope.of(context).requestFocus(FocusNode());

    final years = _availableYears;
    if (years.isEmpty) return;

    int tempIndex = years.indexOf(_selectedYear);
    if (tempIndex < 0) tempIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext bottomSheetContext) {
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
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const Text(
                      '年を選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = years[tempIndex];
                        });
                        Navigator.pop(bottomSheetContext);
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

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('お金の使い方'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(
                  child: Text('まだ支出がありません'),
                )
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _PeriodSelector(
                        selectedPeriod: _selectedPeriod,
                        onChanged: (period) {
                          setState(() {
                            _selectedPeriod = period;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_selectedPeriod == _UsagePeriod.byYear)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _YearPickerButton(
                            selectedYear: _selectedYear,
                            onTap: _showYearPicker,
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SummaryCard(
                        title: _selectedPeriodLabel,
                        totalAmount: _totalAmount,
                        allTimeTotal: _allTimeTotal,
                        previousPeriodTotal: _previousPeriodTotal,
                        comparisonLabel: _comparisonLabel,
                        expenseCount: _filteredExpenses.length,
                        remainingBudget: _remainingBudget,
                        showRemaining: _relevantBudgetHistories.isNotEmpty,
                        yenFormatter: _yenFormatter,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'カテゴリ別',
                        children: _categoryTotals
                            .map(
                              (row) => _AmountListTile(
                                label: row.label,
                                amount: row.amount,
                                totalAmount: _totalAmount,
                                yenFormatter: _yenFormatter,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'お店別 TOP10',
                        children: _storeTotals
                            .map(
                              (row) => _AmountListTile(
                                label: row.label,
                                amount: row.amount,
                                totalAmount: _totalAmount,
                                yenFormatter: _yenFormatter,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int totalAmount;
  final int allTimeTotal;
  final int previousPeriodTotal;
  final String comparisonLabel;
  final int expenseCount;
  final int remainingBudget;
  final bool showRemaining;
  final NumberFormat yenFormatter;

  const _SummaryCard({
    required this.title,
    required this.totalAmount,
    required this.allTimeTotal,
    required this.previousPeriodTotal,
    required this.comparisonLabel,
    required this.expenseCount,
    required this.remainingBudget,
    required this.showRemaining,
    required this.yenFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = totalAmount - previousPeriodTotal;
    final hasComparison = comparisonLabel.isNotEmpty;
    final isIncrease = difference > 0;
    final differenceText = difference == 0
        ? '±0円'
        : '${isIncrease ? '+' : '-'}¥${yenFormatter.format(difference.abs())}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$titleの使った総額',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${yenFormatter.format(totalAmount)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '記録数: $expenseCount件',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
          ),
          if (hasComparison) ...[
            const SizedBox(height: 6),
            Text(
              '$comparisonLabel: $differenceText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: difference == 0
                    ? Colors.black54
                    : isIncrease
                        ? const Color(0xFFC7511F)
                        : const Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showRemaining) ...[
            const SizedBox(height: 8),
            Text(
              remainingBudget >= 0
                  ? '$titleで余った額: ¥${yenFormatter.format(remainingBudget)}'
                  : '$titleでオーバー: ¥${yenFormatter.format(remainingBudget.abs())}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: remainingBudget >= 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC7511F),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '全期間合計: ¥${yenFormatter.format(allTimeTotal)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E6DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._withDividers(children),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      widgets.add(items[i]);
      if (i != items.length - 1) {
        widgets.add(const Divider(height: 20));
      }
    }
    return widgets;
  }
}

class _AmountListTile extends StatelessWidget {
  final String label;
  final int amount;
  final int totalAmount;
  final NumberFormat yenFormatter;

  const _AmountListTile({
    required this.label,
    required this.amount,
    required this.totalAmount,
    required this.yenFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = totalAmount == 0 ? 0 : (amount / totalAmount * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '¥${yenFormatter.format(amount)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${ratio.toStringAsFixed(1)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}



class _AmountRow {
  final String label;
  final int amount;

  const _AmountRow({
    required this.label,
    required this.amount,
  });
}

class _PeriodSelector extends StatelessWidget {
  final _UsagePeriod selectedPeriod;
  final ValueChanged<_UsagePeriod> onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PeriodChip(
          label: '今月',
          selected: selectedPeriod == _UsagePeriod.thisMonth,
          onTap: () => onChanged(_UsagePeriod.thisMonth),
        ),
        _PeriodChip(
          label: '先月',
          selected: selectedPeriod == _UsagePeriod.lastMonth,
          onTap: () => onChanged(_UsagePeriod.lastMonth),
        ),
        _PeriodChip(
          label: '年別',
          selected: selectedPeriod == _UsagePeriod.byYear,
          onTap: () => onChanged(_UsagePeriod.byYear),
        ),
        _PeriodChip(
          label: '全期間',
          selected: selectedPeriod == _UsagePeriod.all,
          onTap: () => onChanged(_UsagePeriod.all),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE6D8) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFFB38A) : const Color(0xFFE9DDD4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF9E4E1F) : Colors.black87,
          ),
        ),
      ),
    );
  }
}


class _YearPickerButton extends StatelessWidget {
  final int selectedYear;
  final VoidCallback onTap;

  const _YearPickerButton({
    required this.selectedYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE9DDD4)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedYear年',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}