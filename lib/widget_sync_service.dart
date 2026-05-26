import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

class WidgetDangerCategory {
  final String name;
  final int remaining;
  final String badge;
  final int budget;

  const WidgetDangerCategory({
    required this.name,
    required this.remaining,
    required this.badge,
    required this.budget,
  });
}

class WidgetSyncService {
  static const String appGroupId = 'group.com.matayoshi.walletdays';
  static const String iOSWidgetName = 'QuicklyAdd';
  static const String androidWidgetName = 'WalletDaysWidgetProvider';
  static const String remainingBudgetKey = 'remaining_budget';
  static const String remainingAmountTextKey = 'remaining_amount_text';
  static const String titleKey = 'quick_add_title';
  static const String remainingTitleKey = 'quick_add_remaining_title';
  static const String totalBudgetKey = 'total_budget';

  // Danger categories (max 2)
  static const String danger1NameKey = 'danger_category_1_name';
  static const String danger1RemainingKey = 'danger_category_1_remaining';
  static const String danger1BadgeKey = 'danger_category_1_badge';
  static const String danger1BudgetKey = 'danger_category_1_budget';

  static const String danger2NameKey = 'danger_category_2_name';
  static const String danger2RemainingKey = 'danger_category_2_remaining';
  static const String danger2BadgeKey = 'danger_category_2_badge';
  static const String danger2BudgetKey = 'danger_category_2_budget';

  static Future<String> _currentLang() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString('app_language');
    if (override != null) return override;
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return device == 'ja' ? 'ja' : 'en';
  }

  static String _t(String lang, String ja, String en) {
    return lang == 'ja' ? ja : en;
  }

  static Future<void> updateRemainingBudget(
    int remaining, {
    required int totalBudget,
    List<WidgetDangerCategory> dangerCategories = const [],
  }) async {
    await HomeWidget.setAppGroupId(appGroupId);

    await HomeWidget.saveWidgetData<int>(remainingBudgetKey, remaining);

    await HomeWidget.saveWidgetData<int>(totalBudgetKey, totalBudget);

    final lang = await _currentLang();
    final formatted = _formatMoney(remaining, lang);
    await HomeWidget.saveWidgetData<String>(
      remainingAmountTextKey,
      formatted,
    );

    await HomeWidget.saveWidgetData<String>(
      titleKey,
      _t(lang, 'クイック追加', 'Quick Add'),
    );
    await HomeWidget.saveWidgetData<String>(
      remainingTitleKey,
      _t(lang, '今月あと', 'Remaining this month'),
    );

    final first = dangerCategories.isNotEmpty ? dangerCategories[0] : null;
    final second = dangerCategories.length > 1 ? dangerCategories[1] : null;

    await HomeWidget.saveWidgetData<String>(
      danger1NameKey,
      first?.name ?? '',
    );
    await HomeWidget.saveWidgetData<int>(
      danger1RemainingKey,
      first?.remaining ?? 0,
    );
    await HomeWidget.saveWidgetData<String>(
      danger1BadgeKey,
      first?.badge ?? '',
    );
    await HomeWidget.saveWidgetData<int>(
      danger1BudgetKey,
      first?.budget ?? 0,
    );

    await HomeWidget.saveWidgetData<String>(
      danger2NameKey,
      second?.name ?? '',
    );
    await HomeWidget.saveWidgetData<int>(
      danger2RemainingKey,
      second?.remaining ?? 0,
    );
    await HomeWidget.saveWidgetData<String>(
      danger2BadgeKey,
      second?.badge ?? '',
    );
    await HomeWidget.saveWidgetData<int>(
      danger2BudgetKey,
      second?.budget ?? 0,
    );

    try {
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        name: androidWidgetName,
      );
    } catch (_) {
      // Widget update should not block saving budget or expenses.
    }
  }

  static String _formatMoney(int amount, String lang) {
    if (lang == 'ja') {
      final sign = amount < 0 ? '-' : '';
      final value = amount.abs().toString();
      final formatted = value.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
      return '$sign$formatted円';
    }

    final dollars = amount / 100.0;
    return '\$${dollars.toStringAsFixed(2)}';
  }
}