import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountDeletePage extends StatefulWidget {
  const AccountDeletePage({super.key});

  @override
  State<AccountDeletePage> createState() => _AccountDeletePageState();
}

class _AccountDeletePageState extends State<AccountDeletePage> {
  bool _isDeleting = false;
  bool _confirmed = false;
  String? _languageOverride;

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

  Future<void> _deleteAccount() async {
    if (_isDeleting || !_confirmed) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      // 匿名ユーザー or ログインユーザーで分岐
      if (user != null && user.isAnonymous) {
        // サーバー削除は不要（ローカルのみ）
        await Supabase.instance.client.auth.signOut();
      } else {
        // ログインユーザーはサーバー削除
        await Supabase.instance.client.rpc('delete_user');
        await Supabase.instance.client.auth.signOut();
      }
      // ローカルデータ（Isar）削除
      try {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open([], directory: dir.path);
        await isar.writeTxn(() async {
          await isar.clear();
        });
        await isar.close();
      } catch (_) {
        // 失敗しても続行
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('アカウントを削除しました', 'Account deleted'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('ご利用ありがとうございました。', 'Thank you for using the app.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_t('閉じる', 'Close')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('アカウント削除に失敗しました', 'Failed to delete account')),
        ),
      );
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('アカウント削除', 'Delete account')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0F0F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('アカウントを削除します', 'Delete your account'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                    ),
                    child: Text(
                      _t(
                        'この操作を行うと、アカウントに紐づくデータは削除されます。\n\n'
                        '・ログイン情報\n'
                        '・バックアップ済みデータ\n'
                        '・プレミアム関連のアカウント情報\n\n'
                        '一度削除すると元に戻せません。',
                        'This action will delete all data linked to your account.\n\n'
                        '• Login information\n'
                        '• Backup data\n'
                        '• Premium account information\n\n'
                        'This action cannot be undone.'
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.65,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0E0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _confirmed,
                          activeColor: Colors.redAccent,
                          onChanged: _isDeleting
                              ? null
                              : (value) {
                                  setState(() {
                                    _confirmed = value ?? false;
                                  });
                                },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _t('上記を理解し、アカウント削除に同意します', 'I understand and agree to delete my account'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (!_confirmed || _isDeleting) ? null : _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFDDDDDD),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isDeleting
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
                                Text(_t('削除中...', 'Deleting...')),
                              ],
                            )
                          : Text(_t('アカウントを削除する', 'Delete account')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isDeleting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_t('やめる', 'Cancel')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}