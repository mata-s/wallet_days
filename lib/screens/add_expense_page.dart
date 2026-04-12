import 'package:flutter/material.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/services/expense_sync_service.dart';
import 'package:saiyome/services/roast_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saiyome/main.dart' show flutterLocalNotificationsPlugin;
import 'package:saiyome/utils/time_provider.dart';
import 'package:timezone/timezone.dart' as tz;
// import 'package:saiyome/screens/receipt_scan_page.dart';

class AddExpensePage extends StatefulWidget {
  final Expense? initialExpense;

  const AddExpensePage({
    super.key,
    this.initialExpense,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();

  final NumberFormat _yenFormatter = NumberFormat('#,###');

  String? _selectedCategory;
  List<BudgetCategory> _categories = [];
  List<String> _frequentStores = [];
  
  Map<String, List<int>> _storeAmounts = {};

  @override
  void initState() {
    super.initState();

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      if (text.isEmpty) return;

      final value = int.tryParse(text);
      if (value == null) return;

      final formatted = _yenFormatter.format(value);

      if (formatted != _amountController.text) {
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
    final initialExpense = widget.initialExpense;
    if (initialExpense != null) {
      _amountController.text = initialExpense.amount.toString();
      _storeController.text = initialExpense.storeName;
      _selectedCategory = initialExpense.category;
    }

    _loadCategories();
    _loadFrequentStores();
  }

  Future<void> _loadCategories() async {
    final budgetSetting = await IsarService.getBudgetSetting();
    if (!mounted) return;

    final categories = budgetSetting?.categories ?? [];

    setState(() {
      _categories = categories;

      if (!_categories.any((c) => c.name == 'その他')) {
        _categories = [
          ..._categories,
          BudgetCategory()
            ..name = 'その他'
            ..badge = '✨'
            ..budget = 0,
        ];
      }
      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories.first.name;
      }
    });
  }

Future<void> _loadFrequentStores() async {
  final expenses = await IsarService.getExpenses();
  if (!mounted) return;

  final Map<String, int> countMap = {};
  final Map<String, Map<int, int>> amountCountMap = {};

  for (final expense in expenses) {
    final store = expense.storeName.trim();
    if (store.isEmpty) continue;

    countMap[store] = (countMap[store] ?? 0) + 1;

    amountCountMap[store] ??= {};
    amountCountMap[store]![expense.amount] =
        (amountCountMap[store]![expense.amount] ?? 0) + 1;
  }

  final sortedStores = countMap.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });

  final Map<String, List<int>> storeAmounts = {};
  for (final entry in amountCountMap.entries) {
    final sortedAmounts = entry.value.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    storeAmounts[entry.key] = sortedAmounts
        .map((amountEntry) => amountEntry.key)
        .take(4)
        .toList();
  }

  setState(() {
    _frequentStores = sortedStores
        .map((entry) => entry.key)
        .take(8)
        .toList();
    _storeAmounts = storeAmounts;
  });
}

  Future<bool> _isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSavedExpenseNotification(Expense expense) async {
    final budgetSetting = await IsarService.getBudgetSetting();
    final totalBudget = budgetSetting?.totalBudget ?? 0;

    final latestCategoryBudget = budgetSetting?.categories
        .where((category) => category.name == expense.category)
        .map((category) => category.budget)
        .cast<int?>()
        .firstWhere((_) => true, orElse: () => null);

    final expenses = await IsarService.getExpenses();
    final usedAmount = expenses.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );
    final latestCategoryUsed = expenses
        .where((item) => item.category == expense.category)
        .fold<int>(0, (sum, item) => sum + item.amount);

    final roastResult = await RoastService.build(
      totalBudget: totalBudget,
      usedAmount: usedAmount,
      expenses: expenses,
      dangerCategories: const [],
      latestCategoryBudget: latestCategoryBudget,
      latestCategoryUsed: latestCategoryUsed,
      latestCategoryTagUsedAmounts: const {},
    );

    final title = roastResult.title;
    final body = roastResult.notificationBody;

    const androidDetails = AndroidNotificationDetails(
      'saiyome_channel',
      '財布の通知',
      channelDescription: '支出記録後の通知',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      var permissionGranted = await androidPlugin.areNotificationsEnabled();

      if (permissionGranted == false) {
        await androidPlugin.requestNotificationsPermission();
        permissionGranted = await androidPlugin.areNotificationsEnabled();
      }

      debugPrint('[AddExpensePage] notification permissionGranted=$permissionGranted');

      if (permissionGranted == false) {
        debugPrint('[AddExpensePage] notification skipped because permission is denied');
        return;
      }
    } else {
      debugPrint('[AddExpensePage] iOS/macOS: skip Android permission check');
    }

   const notificationId = 900001;

    debugPrint('[AddExpensePage] scheduled notification for 15 minutes later');
    debugPrint('[AddExpensePage] title=$title');
    debugPrint('[AddExpensePage] body=$body');
debugPrint('[AddExpensePage] notificationId=$notificationId');

await flutterLocalNotificationsPlugin.cancel(id: notificationId);

await flutterLocalNotificationsPlugin.zonedSchedule(
  id: notificationId,
  title: title,
  body: body,
  scheduledDate: tz.TZDateTime.now(tz.local).add(
    const Duration(minutes: 15),
  ),
  notificationDetails: details,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);
  }
  // Future<void> _openReceiptScanPage() async {
  //   final isPremium = await _isPremiumUser();

  //   if (!isPremium) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('プレミアム機能です')),
  //     );
  //     return;
  //   }

  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => const ReceiptScanPage(),
  //     ),
  //   );

  //   if (result == null) return;

  //   final store = result['store'];
  //   final amount = result['amount'];

  //   if (store != null) {
  //     _storeController.text = store;
  //   }

  //   if (amount != null) {
  //     _amountController.text = amount.toString();
  //   }
  // }

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();
    final store = _storeController.text.trim();

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カテゴリを設定してください')),
      );
      return;
    }

    if (amountText.isEmpty || store.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額と店名を入力してください')),
      );
      return;
    }

    final amount = int.tryParse(amountText.replaceAll(',', ''));

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額は数字で入力してください')),
      );
      return;
    }

    final expense = Expense()
      ..amount = amount
      ..storeName = store
      ..category = _selectedCategory!
      ..createdAt = getNow()
      ..roastMessage = '昨日の$store、見ましたよ。';

    if (widget.initialExpense != null) {
      expense.id = widget.initialExpense!.id;
      expense.createdAt = widget.initialExpense!.createdAt;
      expense.futureLogMessage = widget.initialExpense!.futureLogMessage;
      expense.roastMessage = widget.initialExpense!.roastMessage;
    }
    await IsarService.saveExpense(expense);

    final isPremium = await _isPremiumUser();
    if (isPremium) {
      await ExpenseSyncService.syncExpense(expense);
    }
    debugPrint('[AddExpensePage] calling notification after save');
    await _showSavedExpenseNotification(expense);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialExpense == null ? '支出を追加' : '支出を編集'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 一旦非表示（レシート機能）
              // TextButton.icon(
              //   onPressed: _openReceiptScanPage,
              //   icon: const Icon(Icons.receipt_long),
              //   label: const Text('レシートを読み込む（プレミアム）'),
              // ),
              // const SizedBox(height: 12),
              Text('店名・サービス名', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _storeController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '例: スタバ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_frequentStores.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'よく使うお店',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _frequentStores.map((store) {
                    return ActionChip(
                      label: Text(store),
                      onPressed: () {
                        setState(() {
                          _storeController.text = store;
                          _storeController.selection = TextSelection.collapsed(
                            offset: _storeController.text.length,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                 Text('金額', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '例: 700',
                  border: OutlineInputBorder(),
                  suffixText: '円',
                ),
              ),
              if (_storeController.text.trim().isNotEmpty &&
    (_storeAmounts[_storeController.text.trim()] ?? []).isNotEmpty) ...[
  const SizedBox(height: 10),
  Text(
    'よく使う金額',
    style: theme.textTheme.bodySmall?.copyWith(
      color: Colors.black54,
      fontWeight: FontWeight.w600,
    ),
  ),
  const SizedBox(height: 8),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: (_storeAmounts[_storeController.text.trim()] ?? [])
        .map((amount) {
      return ActionChip(
        label: Text('${_yenFormatter.format(amount)}円'),
        onPressed: () {
          setState(() {
            _amountController.text = amount.toString();
            _amountController.selection = TextSelection.collapsed(
              offset: _amountController.text.length,
            );
          });
        },
      );
    }).toList(),
  ),
],
              ],
              const SizedBox(height: 20),
              Text('カテゴリ', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_categories.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: const Text(
                    '先に予算設定でカテゴリを登録してください',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._categories.map((category) {
                      final isSelected = _selectedCategory == category.name;

                      return ChoiceChip(
                        label: Text('${category.badge} ${category.name}'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category.name;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              if (_selectedCategory == 'その他')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '※ その他は、カテゴリーにない急な出費のときに使います',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
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