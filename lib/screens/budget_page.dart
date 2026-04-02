import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/screens/income_fixed_cost_page.dart';
import 'package:saiyome/services/budget_setting_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';

class ThousandsFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(',', '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) return newValue;

    final newText = _formatter.format(number);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final Map<String, List<String>> _badgeGroups = {
    '食費・飲食': ['🍚', '🍜', '☕️', '🍔', '🍺', '🍰'],
    '買い物・生活': ['🏪', '🛒', '🧻', '🧴', '👕', '💄'],
    '移動・住まい': ['🚃', '🚗', '⛽️', '🏠', '💡', '📱'],
    '健康・美容': ['💊', '💇‍♀️'],
    '趣味・娯楽': ['🎮', '🎬', '🎵', '📚', '🎨', '🎯'],
    'お金・その他': ['🎁', '💰', '💳', '✨'],
  };

  final TextEditingController _totalBudgetController =
      TextEditingController();
  final TextEditingController _extraAmountController =
      TextEditingController();

  final List<Map<String, dynamic>> _categoryControllers = [
    {
      'nameController': TextEditingController(),
      'budgetController': TextEditingController(),
      'badge': '🍚',
    },
  ];

  bool _useCategoryBudget = true;

  int _cycleStartDay = 1;
  int _manualBudgetBuffer = 0;
  int _usableBudgetBase = 0;

  Future<bool> _isPremiumUser() async {
  try {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey('premium');
  } catch (_) {
    return false;
  }
}

  @override
void initState() {
  super.initState();
  _loadBudgetSetting();
  _loadIncomeFixedCostSetting();
}

Future<void> _loadBudgetSetting() async {
  final budgetSetting = await IsarService.getBudgetSetting();
  if (budgetSetting == null || !mounted) return;

  for (final item in _categoryControllers) {
    (item['nameController'] as TextEditingController).dispose();
    (item['budgetController'] as TextEditingController).dispose();
  }
  _categoryControllers.clear();

  _totalBudgetController.text = budgetSetting.totalBudget == 0
      ? ''
      : NumberFormat('#,###').format(budgetSetting.totalBudget);

  _useCategoryBudget = budgetSetting.useCategoryBudget;
  _manualBudgetBuffer = (budgetSetting.totalBudget -
          budgetSetting.categories.fold<int>(
            0,
            (sum, category) => sum + category.budget,
          ))
      .clamp(0, 1 << 30);
  _extraAmountController.text = _manualBudgetBuffer == 0
      ? ''
      : NumberFormat('#,###').format(_manualBudgetBuffer);

  _cycleStartDay = budgetSetting.cycleStartDay == 0 ? 1 : budgetSetting.cycleStartDay;

  if (budgetSetting.categories.isEmpty) {
    _categoryControllers.add({
      'nameController': TextEditingController(),
      'budgetController': TextEditingController(),
      'badge': '🍚',
    });
  } else {
    for (final category in budgetSetting.categories) {
      _categoryControllers.add({
        'nameController': TextEditingController(text: category.name),
        'budgetController': TextEditingController(
          text: category.budget == 0
              ? ''
              : NumberFormat('#,###').format(category.budget),
        ),
        'badge': category.badge,
      });
    }
  }

  setState(() {});
}

Future<void> _loadIncomeFixedCostSetting() async {
  final setting = await IsarService.getIncomeFixedCostSetting();
  if (!mounted) return;

  setState(() {
    if (setting == null) {
      _usableBudgetBase = 0;
    } else {
      _usableBudgetBase = setting.income - setting.fixedCostTotal;
      if (_usableBudgetBase < 0) {
        _usableBudgetBase = 0;
      }
    }
  });
}

DateTime _currentPeriodStart(DateTime now) {
  final startDay = _cycleStartDay.clamp(1, 28);
  if (now.day >= startDay) {
    return DateTime(now.year, now.month, startDay);
  }
  return DateTime(now.year, now.month - 1, startDay);
}

DateTime _currentPeriodEnd(DateTime periodStart) {
  return DateTime(
    periodStart.year,
    periodStart.month + 1,
    periodStart.day,
  ).subtract(const Duration(days: 1));
}

  int get _categoryBudgetSum {
    int total = 0;
    for (final item in _categoryControllers) {
      final budgetController = item['budgetController'] as TextEditingController;
      final text = budgetController.text.replaceAll(',', '').trim();
      final value = int.tryParse(text) ?? 0;
      total += value;
    }
    return total;
  }

  int get _currentTotalBudgetValue {
    return int.tryParse(_totalBudgetController.text.replaceAll(',', '').trim()) ?? 0;
  }

  int get _remainingUsableBudget {
    return _usableBudgetBase - _currentTotalBudgetValue;
  }
  
  bool get _hasUsableBudgetBase {
    return _usableBudgetBase > 0;
  }

  int get _budgetExtraAmount {
    return int.tryParse(_extraAmountController.text.replaceAll(',', '').trim()) ?? 0;
  }

  void _setExtraAmountValue(int value) {
    final safeValue = value < 0 ? 0 : value;
    _manualBudgetBuffer = safeValue;
    _extraAmountController.text =
        safeValue == 0 ? '' : NumberFormat('#,###').format(safeValue);
  }

  void _syncExtraAmountFromTotalBudget() {
    final extra = _currentTotalBudgetValue - _categoryBudgetSum;
    _setExtraAmountValue(extra < 0 ? 0 : extra);
  }

  void _syncTotalBudgetFromExtraAmount() {
    if (!_useCategoryBudget) return;

    final nextTotal = _categoryBudgetSum + _budgetExtraAmount;
    _totalBudgetController.text = nextTotal == 0
        ? ''
        : NumberFormat('#,###').format(nextTotal);
  }

  void _syncTotalBudgetWithCategorySum({bool preserveCurrentDifference = true}) {
    if (!_useCategoryBudget) return;

    if (preserveCurrentDifference) {
      _syncExtraAmountFromTotalBudget();
    }

    final nextTotal = _categoryBudgetSum + _budgetExtraAmount;
    _totalBudgetController.text = nextTotal == 0
        ? ''
        : NumberFormat('#,###').format(nextTotal);
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    _extraAmountController.dispose();
    for (final item in _categoryControllers) {
      item['nameController'].dispose();
      item['budgetController'].dispose();
    }
    super.dispose();
  }

  Future<void> _saveBudget() async  {
    final totalBudgetText = _totalBudgetController.text.replaceAll(',', '').trim();

    if (!_useCategoryBudget && totalBudgetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全体予算を入力してください')),
      );
      return;
    }

    final validCategories = <Map<String, String>>[];

    for (final item in _categoryControllers) {
      final nameController = item['nameController'] as TextEditingController;
      final budgetController = item['budgetController'] as TextEditingController;
      final badge = item['badge'] as String;

      final name = nameController.text.trim();
      final budgetText = budgetController.text.replaceAll(',', '').trim();

      final isNameEmpty = name.isEmpty;
      final isBudgetEmpty = budgetText.isEmpty;

      if (isNameEmpty && isBudgetEmpty) {
        continue;
      }

      if (isNameEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カテゴリー名を入力してください')),
        );
        return;
      }

      if (isBudgetEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$name」の予算を入力してください')),
        );
        return;
      }

      validCategories.add({
        'name': name,
        'budget': budgetText,
        'badge': badge,
      });
    }

final totalBudget = int.tryParse(totalBudgetText) ?? 0;

final budgetSetting = BudgetSetting()
  ..totalBudget = totalBudget
  ..useCategoryBudget = _useCategoryBudget
  ..cycleStartDay = _cycleStartDay
  ..updatedAt = DateTime.now();

budgetSetting.categories = validCategories.map((e) {
  return BudgetCategory()
    ..name = e['name'] ?? ''
    ..budget = int.tryParse(e['budget'] ?? '0') ?? 0
    ..badge = e['badge'] ?? '✨';
}).toList();

await IsarService.saveBudgetSetting(budgetSetting);

final now = DateTime.now();
final periodStart = _currentPeriodStart(now);
final periodEnd = _currentPeriodEnd(periodStart);

final existingHistory = await IsarService.getBudgetHistoryByPeriod(
  periodStart,
  periodEnd,
);

final history = existingHistory ?? BudgetHistory();
history
  ..startDate = periodStart
  ..endDate = periodEnd
  ..totalBudget = totalBudget
  ..totalExpense = existingHistory?.totalExpense ?? 0
  ..isAchieved = existingHistory?.isAchieved ?? false
  ..streak = existingHistory?.streak ?? 0
  ..createdAt = existingHistory?.createdAt ?? now;

await IsarService.saveBudgetHistory(history);

final isPremium = await _isPremiumUser();
if (isPremium) {
  await BudgetSettingSyncService.syncBudgetSetting(budgetSetting);
  await BudgetHistorySyncService.syncBudgetHistory(history);
}
if (!mounted) return;
Navigator.pop(context, true);
  }

  void _showCycleStartDayPicker() {
    int tempIndex = _cycleStartDay - 1;
    FocusScope.of(context).requestFocus(FocusNode());

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
                      '開始日を選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _cycleStartDay = tempIndex + 1;
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
                  children: List.generate(28, (index) {
                    final day = index + 1;
                    return Center(
                      child: Text(
                        '毎月 $day 日から',
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartDayCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '開始日',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ここから1ヶ月で集計',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showCycleStartDayPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '毎月 $_cycleStartDay 日から',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '収入と固定費',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '使えるお金の前提',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncomeFixedCostPage(),
                ),
              );

              if (!mounted) return;

              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();

              if (result != null) {
                await _loadIncomeFixedCostSetting();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '確認する',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 380;

  return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('予算設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          isNarrow
              ? Column(
                  children: [
                    _buildStartDayCard(theme),
                    const SizedBox(height: 12),
                    _buildIncomeCard(theme),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStartDayCard(theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildIncomeCard(theme)),
                  ],
                ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '今月の全体予算',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 6),
    Text(
      'カテゴリを振り分ける前に、今月の上限を決めます。',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.black54,
        height: 1.4,
      ),
    ),
    const SizedBox(height: 12),
    if (_hasUsableBudgetBase) ...[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今月の使える予算',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${NumberFormat('#,###').format(_usableBudgetBase)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'あと使える金額',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _remainingUsableBudget >= 0
                  ? '¥${NumberFormat('#,###').format(_remainingUsableBudget)}'
                  : '-¥${NumberFormat('#,###').format(_remainingUsableBudget.abs())}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _remainingUsableBudget < 0 ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ],
    TextField(
      controller: _totalBudgetController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsFormatter(),
      ],
      onChanged: (_) {
        if (!_useCategoryBudget) {
          setState(() {});
          return;
        }
        setState(() {
          _syncExtraAmountFromTotalBudget();
        });
      },
      decoration: InputDecoration(
        labelText: '予算',
        hintText: '50,000',
        suffixText: '円',
        border: const OutlineInputBorder(),
        helperText: _useCategoryBudget
            ? 'カテゴリ合計 ¥${NumberFormat('#,###').format(_categoryBudgetSum)} を反映中'
            : null,
      ),
    ),
  ],
),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('カテゴリ別予算を設定する'),
                  value: _useCategoryBudget,
                  onChanged: (value) {
                    setState(() {
                      _useCategoryBudget = value;
                      if (_useCategoryBudget) {
                        _syncExtraAmountFromTotalBudget();
                        _syncTotalBudgetWithCategorySum(
                          preserveCurrentDifference: false,
                        );
                      }
                    });
                  },
                ),
                if (_useCategoryBudget) ...[
                  const SizedBox(height: 8),
                  ..._categoryControllers.map((item) {
                    final nameController = item['nameController'] as TextEditingController;
                    final budgetController = item['budgetController'] as TextEditingController;
                    final badge = item['badge'] as String;
                    final isNarrow = MediaQuery.of(context).size.width <= 380;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  FocusScope.of(context).requestFocus(FocusNode());

                                  final selected = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('バッジを選択'),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: _badgeGroups.entries.map((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        entry.key,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Wrap(
                                                        spacing: 12,
                                                        runSpacing: 12,
                                                        children: entry.value.map((emoji) {
                                                          return GestureDetector(
                                                            onTap: () =>
                                                                Navigator.pop(context, emoji),
                                                            child: Container(
                                                              width: 52,
                                                              height: 52,
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(
                                                                color: emoji == badge
                                                                    ? const Color(0xFFFFF1EA)
                                                                    : Colors.white,
                                                                borderRadius:
                                                                    BorderRadius.circular(16),
                                                                border: Border.all(
                                                                  color:
                                                                      const Color(0xFFE0E0E0),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                emoji,
                                                                style: const TextStyle(
                                                                    fontSize: 24),
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('閉じる'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (selected != null) {
                                    setState(() {
                                      item['badge'] = selected;
                                    });

                                    FocusScope.of(context).unfocus();
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EA),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE8D9D2),
                                    ),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'カテゴリ名',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (!isNarrow)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_categoryControllers.length == 1) {
                                        nameController.clear();
                                        budgetController.clear();
                                        item['badge'] = '🍚';
                                      } else {
                                        nameController.dispose();
                                        budgetController.dispose();
                                        _categoryControllers.remove(item);
                                      }

                                      _syncTotalBudgetWithCategorySum(
                                        preserveCurrentDifference: false,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'カテゴリ削除',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: budgetController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsFormatter(),
                            ],
                            onChanged: (_) {
                              setState(() {
                                _syncTotalBudgetWithCategorySum(
                                  preserveCurrentDifference: false,
                                );
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: '予算',
                              hintText: '20,000',
                              suffixText: '円',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (isNarrow) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_categoryControllers.length == 1) {
                                      nameController.clear();
                                      budgetController.clear();
                                      item['badge'] = '🍚';
                                    } else {
                                      nameController.dispose();
                                      budgetController.dispose();
                                      _categoryControllers.remove(item);
                                    }

                                    _syncTotalBudgetWithCategorySum(
                                      preserveCurrentDifference: false,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('削除'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _categoryControllers.add({
                            'nameController': TextEditingController(),
                            'budgetController': TextEditingController(),
                            'badge': '🍚',
                          });
                          _syncTotalBudgetWithCategorySum(
                            preserveCurrentDifference: false,
                          );
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'カテゴリ追加',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'カテゴリ外で使える金額',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _extraAmountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ThousandsFormatter(),
                          ],
                          onChanged: (_) {
                            if (!_useCategoryBudget) return;
                            setState(() {
                              _syncTotalBudgetFromExtraAmount();
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'カテゴリ外で使える金額',
                            hintText: '2,000',
                            suffixText: '円',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saveBudget,
              child: const Text('予算を保存'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}