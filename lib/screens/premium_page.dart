import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/expense_sync_service.dart';
import 'package:saiyome/services/budget_setting_sync_service.dart';
import 'package:saiyome/services/income_fixed_cost_sync_service.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:saiyome/screens/backup_restore_page.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _isCompleted = false;
  bool _shouldShowRegisterPrompt() {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return false;
    return authUser.isAnonymous;
  }

  Package? _monthlyPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isCompletingPurchase = false;
  bool _isPremium = false;
  String? _errorMessage;
  String? _lastBackupFailedStep;
  String? _languageOverride; // 'ja' or 'en'

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadOfferings();
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

  Future<void> _openLegalPage(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await Purchases.getOfferings();
      final monthly = offerings.current?.monthly;
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey('premium');

      setState(() {
        _monthlyPackage = monthly;
        _isPremium = isPremium;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _t('プラン情報の取得に失敗しました', 'Failed to load plan information');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase() async {
    final package = _monthlyPackage;
    if (package == null) return;

    setState(() {
      _isPurchasing = true;
      _isCompletingPurchase = false;
      _errorMessage = null;
      _lastBackupFailedStep = null;
    });

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium =
          customerInfo.entitlements.active.containsKey('premium');

      if (!mounted) return;

      if (!isPremium) {
        setState(() {
          _errorMessage = _t('購入は完了しましたが、プレミアム状態を確認できませんでした', 'Purchase completed, but Premium status could not be confirmed');
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isCompletingPurchase = true;
        _isPremium = true;
      });

      final backupSucceeded = await _runInitialBackup();
      if (backupSucceeded) {
        setState(() {
          _isCompleted = true;
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;

      bool shouldOpenRegister = false;

      if (backupSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('プレミアム登録が完了しました', 'Premium registration completed'))),
        );
        if (_shouldShowRegisterPrompt()) {
          shouldOpenRegister = await _showRegisterPrompt();
        }
      } else {
        await _showBackupFailedDialog();
        if (!mounted) return;
        if (_shouldShowRegisterPrompt()) {
          shouldOpenRegister = await _showRegisterPrompt();
        }
      }

      if (!mounted) return;
      if (shouldOpenRegister) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BackupRestorePage(
              showSignUpTab: true,
              initialIsSignUp: true,
            ),
          ),
        );
      }

      if (!mounted) return;
     setState(() {});
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        setState(() {
          _errorMessage = _t('購入を完了できませんでした', 'Could not complete purchase');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _t('エラーが発生しました', 'An error occurred');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isCompletingPurchase = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _isCompletingPurchase = false;
      _errorMessage = null;
      _lastBackupFailedStep = null;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium =
          customerInfo.entitlements.active.containsKey('premium');

      if (!mounted) return;

      if (isPremium) {
        setState(() {
          _isCompletingPurchase = true;
        });
        final backupSucceeded = await _runInitialBackup();
        if (backupSucceeded) {
          setState(() {
            _isCompleted = true;
          });
          await Future.delayed(const Duration(seconds: 1));
        }

        if (!mounted) return;

        bool shouldOpenRegister = false;

        if (backupSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('購入情報を復元しました', 'Purchases restored'))),
          );
          if (_shouldShowRegisterPrompt()) {
            shouldOpenRegister = await _showRegisterPrompt();
          }
        } else {
          await _showBackupFailedDialog();
          if (!mounted) return;
          if (_shouldShowRegisterPrompt()) {
            shouldOpenRegister = await _showRegisterPrompt();
          }
        }

        if (!mounted) return;
        if (shouldOpenRegister) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BackupRestorePage(
                showSignUpTab: true,
                initialIsSignUp: true,
              ),
            ),
          );
        }

        if (!mounted) return;
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('復元できる購入情報がありませんでした', 'No purchases found to restore'))),
        );
      }
    } on PlatformException catch (_) {
      setState(() {
        _errorMessage = _t('復元に失敗しました', 'Failed to restore purchases');
      });
    } catch (e) {
      setState(() {
        _errorMessage = _t('復元に失敗しました', 'Failed to restore purchases');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isCompletingPurchase = false;
        });
      }
    }
  }

  Future<bool> _runInitialBackup() async {
    _lastBackupFailedStep = null;

    Future<bool> runStep(
      String stepName,
      Future<void> Function() action,
    ) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await action().timeout(const Duration(seconds: 12));
          return true;
        } catch (_) {
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }
      }

      _lastBackupFailedStep = stepName;
      return false;
    }

    final expensesSucceeded = await runStep(_t('支出データ', 'Expense data'), () async {
      final expenses = await IsarService.getExpenses();
      await ExpenseSyncService.syncExpenses(expenses);
    });
    if (!expensesSucceeded) return false;

    final budgetSucceeded = await runStep(_t('予算設定', 'Budget settings'), () async {
      final budgetSetting = await IsarService.getBudgetSetting();
      if (budgetSetting != null) {
        await BudgetSettingSyncService.syncBudgetSetting(budgetSetting);
      }
    });
    if (!budgetSucceeded) return false;

    final incomeFixedCostSucceeded = await runStep(_t('収入・固定費設定', 'Income & fixed costs'), () async {
      final incomeFixedCostSetting =
          await IsarService.getIncomeFixedCostSetting();
      if (incomeFixedCostSetting != null) {
        await IncomeFixedCostSyncService.sync(
          monthlyIncome: incomeFixedCostSetting.income,
          fixedCostTotal: incomeFixedCostSetting.fixedCostTotal,
          items: incomeFixedCostSetting.items
              .map((e) => {
                    'title': e.name,
                    'amount': e.amount,
                  })
              .toList(),
        );
      }
    });
    if (!incomeFixedCostSucceeded) return false;

    final historiesSucceeded = await runStep(_t('予算履歴', 'Budget history'), () async {
      final histories = await IsarService.getBudgetHistories();
      await BudgetHistorySyncService.syncBudgetHistories(histories);
    });
    if (!historiesSucceeded) return false;

    return true;
  }

  Future<void> _showBackupFailedDialog() async {
    final failedStepText = _lastBackupFailedStep == null
        ? ''
        : '\n\n${_t('失敗した項目', 'Failed item')}: $_lastBackupFailedStep';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('プレミアム登録は完了しました', 'Premium registration completed')),
          content: Text(
            _t(
              '購入自体は完了していますが、初回バックアップに失敗しました。'
              '$failedStepText\n\n'
              '通信状況をご確認のうえ、もう一度お試しください。',
              'Your purchase was completed, but the initial backup failed.'
              '$failedStepText\n\n'
              'Please check your connection and try again.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _priceText() {
    final package = _monthlyPackage;
    if (package == null) return _t('月額 120円', '\$1.00 / month');
    return package.storeProduct.priceString;
  }

  String _periodText() {
    final package = _monthlyPackage;
    if (package == null) return _t('1ヶ月ごと', 'monthly');

    final period = package.storeProduct.subscriptionPeriod;
    if (period == null) return _t('1ヶ月ごと', 'monthly');

    final normalized = period.trim().toUpperCase();
    if (normalized.isEmpty) return _t('1ヶ月ごと', 'monthly');

    switch (normalized) {
      case 'P1W':
        return _t('1週間ごと', 'weekly');
      case 'P1M':
        return _t('1ヶ月ごと', 'monthly');
      case 'P2M':
        return _t('2ヶ月ごと', 'every 2 months');
      case 'P3M':
        return _t('3ヶ月ごと', 'every 3 months');
      case 'P6M':
        return _t('6ヶ月ごと', 'every 6 months');
      case 'P1Y':
        return _t('1年ごと', 'yearly');
      default:
        return period;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('プレミアム', 'Premium')),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFBF6),
      Color(0xFFF8F9FC),
    ],
  ),
  borderRadius: BorderRadius.circular(28),
  border: Border.all(color: const Color(0xFFF0F0F0)),
  boxShadow: const [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ],
),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('もっと便利に、もっと続けやすく', 'More useful. Easier to keep going.'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('レポート・称号・上位％表示・バックアップなどのプレミアム機能が使えます', 'Unlock reports, titles, ranking percent, backups, and more'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _priceText(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                       letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                    ),
                    child: Text(
                      _t('自動更新サブスク ・ ${_periodText()}', 'Auto-renewing subscription ・ ${_periodText()}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _featureCard(
              context,
              icon: Icons.insert_chart_outlined_rounded,
              title: _t('レポート', 'Reports'),
              description: _t('月の振り返りを見やすく確認できます', 'Review your month more easily'),
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.emoji_events_outlined,
              title: _t('称号', 'Titles'),
              description: _t('やりくりの達成状況に応じて称号が表示されます', 'Earn titles based on your budgeting progress'),
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.trending_up_rounded,
              title: _t('やりくり上位％', 'Budget rank percentile'),
              description: _t('予算内におさまった月は、みんなの中でどのくらい上手にやりくりできたかがわかります', 'When you stay within budget, see how well you did compared with others'),
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.cloud_outlined,
              title: _t('バックアップ', 'Backup'),
              description: _t('大切なデータを保存して引き継げます', 'Save and restore your important data'),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_isLoading || _isPurchasing || _monthlyPackage == null || _isPremium)
                    ? null
                    : _purchase,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _isPurchasing || _isCompletingPurchase
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isCompletingPurchase
                                    ? _t('登録処理中...', 'Completing registration...')
                                    : _t('購入中...', 'Purchasing...'),
                              ),
                            ],
                          )
                        : _isPremium
                            ? Text(_t('プレミアム登録済み', 'Premium active'))
                            : Text(_t('${_priceText()}で始める', 'Start for ${_priceText()}')),
              ),
            ),
            if (_isCompletingPurchase || _isCompleted) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isCompleted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 36,
                            )
                          : const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isCompleted ? _t('同期が完了しました', 'Sync completed') : _t('同期中です...', 'Syncing...'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCompleted
                          ? _t('すべてのデータが安全に保存されました', 'All data has been safely saved')
                          : _t('初回バックアップを行っています', 'Running the initial backup'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _t('購入について', 'About purchase'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t(
                      '自動更新サブスクリプションです（${_periodText()}）\n'
                      'お支払いは購入確定時に、ご利用のアカウントに請求されます。\n'
                      '現在の期間終了の24時間以上前に解約しない限り自動で更新されます。\n'
                      '解約や管理は、ご利用端末のサブスクリプション設定画面から行えます。\n'
                      '購入には、アプリストアの規約が適用されます。\n'
                      '表示価格は目安であり、実際の請求額や通貨はご利用のストアにより異なる場合があります。',
                      'This is an auto-renewing subscription (${_periodText()}).\n'
                      'Payment will be charged to your account when the purchase is confirmed.\n'
                      'It renews automatically unless canceled at least 24 hours before the end of the current period.\n'
                      'You can cancel or manage it from your device subscription settings.\n'
                      'Purchases are subject to the terms of the applicable app store.\n'
                      'Displayed prices are estimates. The actual charge and currency may vary by store.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _openLegalPage(
                          'https://wallet-days.vercel.app/terms.html',
                        ),
                        child: Text(_t('利用規約', 'Terms of Use')),
                      ),
                      TextButton(
                        onPressed: () => _openLegalPage(
                          'https://wallet-days.vercel.app/privacy.html',
                        ),
                        child: Text(_t('プライバシーポリシー', 'Privacy Policy')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
TextButton(
  onPressed: _isPurchasing ? null : _restorePurchases,
  child: Text(_t('購入を復元', 'Restore purchases')),
),
            const SizedBox(height: 6),
          ],
        ),
          ),

          if (_isPurchasing || _isCompletingPurchase)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isCompletingPurchase
                            ? _t('同期中です...', 'Syncing...')
                            : _t('購入処理中です...', 'Processing purchase...'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<bool> _showRegisterPrompt() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 38,
                    color: Color(0xFF4E6EF2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('メールアドレスを登録しよう', 'Register your email address'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _t('アカウントを作成して、\nデータを引き継げるようにしましょう。', 'Create an account so you can transfer your data.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _t('後で登録できます', 'You can register later'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t('※端末を変更する際は、事前に登録が必要です', 'You need to register before changing devices'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6EF2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _t('登録する', 'Register'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('あとで', 'Later')),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }
}