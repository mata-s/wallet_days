import 'package:flutter/material.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/services/expense_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saiyome/main.dart' show flutterLocalNotificationsPlugin;

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
  }

  Future<void> _loadCategories() async {
    final budgetSetting = await IsarService.getBudgetSetting();
    if (!mounted) return;

    final categories = budgetSetting?.categories ?? [];

    setState(() {
      _categories = categories;

      // 「その他」を常に追加（存在しない場合）
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

  Future<bool> _isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSavedExpenseNotification(Expense expense) async {
    String title = expense.storeName.trim().isNotEmpty
        ? '${expense.storeName} の支出を記録しました。'
        : '支出を記録しました。';

    String body = expense.category == 'その他'
        ? 'その他カテゴリで${_yenFormatter.format(expense.amount)}円の支出を記録しました。'
        : '${expense.category}カテゴリの支出を${_yenFormatter.format(expense.amount)}円で記録しました。';

    const androidDetails = AndroidNotificationDetails(
      'saiyome_channel',
      '財布の通知',
      channelDescription: '支出記録後の通知',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

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
      ..createdAt = DateTime.now()
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
              const SizedBox(height: 20),
              Text('店名・サービス名', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _storeController,
                decoration: const InputDecoration(
                  hintText: '例: スタバ',
                  border: OutlineInputBorder(),
                ),
              ),
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