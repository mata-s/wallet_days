import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/widgets/future_log_item.dart';
import 'package:saiyome/widgets/timeline_item.dart';
import 'package:saiyome/utils/time_provider.dart';

enum TimelineFilterPeriod {
  all,
  today,
  last7Days,
  customMonth,
}

class TimelinePage extends StatefulWidget {
  final List<Expense> expenses;
  final String Function(int) formatYen;
  final String Function(String) categoryLabel;
  final IconData Function(String) iconForCategory;
  final String Function(DateTime) formatTimelineDate;
  final Future<Expense?> Function(Expense)? onEditExpense;
  final Future<bool> Function(Expense)? onDeleteExpense;

  const TimelinePage({
    super.key,
    required this.expenses,
    required this.formatYen,
    required this.categoryLabel,
    required this.iconForCategory,
    required this.formatTimelineDate,
    this.onEditExpense,
    this.onDeleteExpense,
  });

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late List<Expense> _expenses;
  TimelineFilterPeriod _selectedPeriod = TimelineFilterPeriod.all;
  late int _selectedYear;
  late int _selectedMonth;
  String _selectedCategory = 'すべて';

  @override
  void initState() {
    super.initState();
    _expenses = List<Expense>.from(widget.expenses);
    // final now = DateTime.now();
    final now = getNow();
    final years = _availableYears;
    _selectedYear = years.contains(now.year)
        ? now.year
        : (years.isNotEmpty ? years.first : now.year);

    final months = _expenses
        .where((expense) => expense.createdAt.year == _selectedYear)
        .map((expense) => expense.createdAt.month)
        .toSet()
        .toList()
      ..sort();

    _selectedMonth = months.contains(now.month)
        ? now.month
        : (months.isNotEmpty ? months.first : now.month);
  }

  @override
  void didUpdateWidget(covariant TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.expenses, widget.expenses)) {
      _expenses = List<Expense>.from(widget.expenses);
    }
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<int> get _availableYears {
    final years = _expenses
        .map((expense) => expense.createdAt.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    // final nowYear = DateTime.now().year;
    final nowYear = getNow().year;
    if (!years.contains(nowYear)) {
      years.insert(0, nowYear);
    }
    return years;
  }

  List<int> get _availableMonthsForSelectedYear {
    final months = _expenses
        .where((expense) => expense.createdAt.year == _selectedYear)
        .map((expense) => expense.createdAt.month)
        .toSet()
        .toList()
      ..sort();

    return months;
  }

  void _ensureValidSelectedMonth() {
    final months = _availableMonthsForSelectedYear;
    if (months.isEmpty) return;
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.first;
    }
  }

  List<String> get _availableCategories {
    final categories = _expenses
        .map((expense) => widget.categoryLabel(expense.category))
        .toSet()
        .toList()
      ..sort();

    return ['すべて', ...categories];
  }

  bool _matchesPeriod(Expense expense) {
    // final now = DateTime.now();
    final now = getNow();
    final today = _normalize(now);
    final createdAt = _normalize(expense.createdAt);

    switch (_selectedPeriod) {
      case TimelineFilterPeriod.all:
        return true;
      case TimelineFilterPeriod.today:
        return createdAt == today;
      case TimelineFilterPeriod.last7Days:
        final start = today.subtract(const Duration(days: 6));
        return !createdAt.isBefore(start) && !createdAt.isAfter(today);
      case TimelineFilterPeriod.customMonth:
        return createdAt.year == _selectedYear &&
            createdAt.month == _selectedMonth;
    }
  }

  bool _matchesCategory(Expense expense) {
    if (_selectedCategory == 'すべて') return true;
    return widget.categoryLabel(expense.category) == _selectedCategory;
  }

  String _periodLabel(TimelineFilterPeriod period) {
    switch (period) {
      case TimelineFilterPeriod.all:
        return 'すべて';
      case TimelineFilterPeriod.today:
        return '今日';
      case TimelineFilterPeriod.last7Days:
        return '7日間';
      case TimelineFilterPeriod.customMonth:
        return '年月指定';
    }
  }

  void _showYearPicker() {
    final years = _availableYears;
    if (years.isEmpty) return;

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
                          _ensureValidSelectedMonth();
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

  void _showMonthPicker() {
    final months = _availableMonthsForSelectedYear;
    if (months.isEmpty) return;

    int tempIndex = months.indexOf(_selectedMonth);
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
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const Text(
                      '月を選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMonth = months[tempIndex];
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
                  children: months.map((month) {
                    return Center(
                      child: Text(
                        '$month月',
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

  void _showCategoryPicker() {
    final categories = _availableCategories;
    if (categories.isEmpty) return;

    int tempIndex = categories.indexOf(_selectedCategory);
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
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const Text(
                      'カテゴリを選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = categories[tempIndex];
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
                  children: categories.map((category) {
                    return Center(
                      child: Text(
                        category,
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

  List<Expense> get _filteredExpenses {
    return _expenses
        .where((expense) => _matchesPeriod(expense) && _matchesCategory(expense))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TimelineFilterPeriod.values.map((period) {
                      final isSelected = _selectedPeriod == period;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(period)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          selectedColor: Colors.black87,
                          backgroundColor: const Color(0xFFF4F4F4),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showCategoryPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'カテゴリ',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8F9FC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          child: Text(_selectedCategory),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == TimelineFilterPeriod.customMonth) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _showYearPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '年',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            child: Text('$_selectedYear年'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _showMonthPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '月',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            child: Text('$_selectedMonth月'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _filteredExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'この条件に合う支出はありません。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
children: _filteredExpenses.expand((expense) => [
  Dismissible(
    key: ValueKey(expense.id),
    direction: widget.onDeleteExpense != null
        ? DismissDirection.endToStart
        : DismissDirection.none,
    background: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    secondaryBackground: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.delete_outline,
        color: Color(0xFFD64B4B),
        size: 28,
      ),
    ),
    confirmDismiss: widget.onDeleteExpense == null
        ? null
        : (_) async {
            final deleted = await widget.onDeleteExpense!(expense);
            if (deleted == true && mounted) {
              setState(() {
                _expenses.removeWhere((item) => item.id == expense.id);
              });
              return true;
            }
            return false;
          },
    child: TimelineItem(
      title: expense.storeName,
      subtitle: widget.categoryLabel(expense.category),
      amount: '¥${widget.formatYen(expense.amount)}',
      icon: widget.iconForCategory(expense.category),
      date: widget.formatTimelineDate(expense.createdAt),
      onEdit: widget.onEditExpense != null
          ? () async {
              final updatedExpense = await widget.onEditExpense!(expense);
              if (updatedExpense == null || !mounted) return;

              setState(() {
                final index = _expenses.indexWhere(
                  (item) => item.id == updatedExpense.id,
                );
                if (index != -1) {
                  _expenses[index] = updatedExpense;
                }
              });
            }
          : null,
      onDelete: widget.onDeleteExpense != null
          ? () async {
              final deleted = await widget.onDeleteExpense!(expense);
              if (deleted != true || !mounted) return;

              setState(() {
                _expenses.removeWhere((item) => item.id == expense.id);
              });
            }
          : null,
    ),
  ),
  if (expense.futureLogMessage != null) ...[
    const SizedBox(height: 10),
    FutureLogItem(message: expense.futureLogMessage!),
  ],
  const SizedBox(height: 10),
]).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}