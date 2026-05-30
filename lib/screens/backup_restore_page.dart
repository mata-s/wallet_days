import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saiyome/screens/home_page.dart';
import 'package:saiyome/services/account_data_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class BackupRestorePage extends StatefulWidget {
  final bool showSignUpTab;
  final bool initialIsSignUp;

  const BackupRestorePage({
    super.key,
    this.showSignUpTab = true,
    this.initialIsSignUp = true,
  });

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> with WidgetsBindingObserver {
  bool _isSigningIn = false;
  bool _isSyncingAccountData = false;
  late bool _showSignUp;
  bool _obscurePassword = true;
  String? _languageOverride; // 'ja' or 'en'

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  String? _infoMessage;
  String? _emailError;
  String? _passwordError;

  String? _errorMessage;
  String? _pendingLinkedProvider;
  String? _pendingOAuthLoginProvider;
  bool _shouldSyncAfterAuthChange = false;
  int _oauthAttemptId = 0;
  Future<bool> _isCurrentAccountLinked() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final row = await Supabase.instance.client
        .from('profiles')
        .select('is_account_linked')
        .eq('id', user.id)
        .maybeSingle();

    return row?['is_account_linked'] == true;
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


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLanguagePreference();
    _showSignUp = widget.showSignUpTab ? widget.initialIsSignUp : false;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated) {
          _handleAuthStateChanged();
        }
      },
    );
  }

  Future<void> _handleAuthStateChanged() async {
    if (!mounted) return;
    if (_isSyncingAccountData) return;
    if (!_shouldSyncAfterAuthChange) return;

    await _trySyncAfterAuthChange();
  }

  Future<void> _trySyncAfterAuthChange() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_showSignUp) {
      if (user.isAnonymous) return;
    } else if (_pendingOAuthLoginProvider != null) {
      final isLinked = await _isCurrentAccountLinked();
      if (!isLinked) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _isSyncingAccountData = false;
          _shouldSyncAfterAuthChange = false;
          _pendingOAuthLoginProvider = null;
          _pendingLinkedProvider = null;
          _infoMessage = null;
          _errorMessage = _t(
            'このGoogle / Appleアカウントは登録されていません。',
            'This Google / Apple account is not registered.',
          );
        });
        return;
      }
    }

    await _syncAccountDataIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_shouldSyncAfterAuthChange) return;
    if (_isSyncingAccountData) return;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (!_shouldSyncAfterAuthChange) return;
      if (_isSyncingAccountData) return;

      _handleAuthStateChanged();
    });
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  void _clearFieldErrors() {
    _emailError = null;
    _passwordError = null;
  }

  Future<void> _markAccountLinked(String provider) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('profiles').upsert({
      'id': user.id,
      'is_account_linked': true,
      'linked_provider': provider,
      'account_linked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _syncAccountDataIfNeeded() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_isSyncingAccountData) return;

    setState(() {
      _isSyncingAccountData = true;
      _errorMessage = null;
      _clearFieldErrors();
    });

    try {
      final result = await AccountDataSyncService.syncFromCloudToLocal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'データを同期しました（支出${result.expenseCount}件・履歴${result.historyCount}件）',
              'Data synced: ${result.expenseCount} expenses and ${result.historyCount} history records.',
            ),
          ),
        ),
      );
      if (_pendingLinkedProvider != null) {
        await _markAccountLinked(_pendingLinkedProvider!);
        _pendingLinkedProvider = null;
      }
      _pendingOAuthLoginProvider = null;
      _oauthAttemptId++;

      if (!widget.showSignUpTab) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );
      } else {
        // Stay on this page and reflect logged-in state
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _showSignUp
            ? _t('登録後のデータ同期に失敗しました', 'Failed to sync data after sign up.')
            : _t('ログイン後のデータ同期に失敗しました', 'Failed to sync data after log in.');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSyncingAccountData = false;
        _isSigningIn = false;
        _shouldSyncAfterAuthChange = false;
        _pendingOAuthLoginProvider = null;
      });
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    const redirectTo = 'walletdays://login-callback';
    final attemptId = ++_oauthAttemptId;
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _infoMessage = null;
      _clearFieldErrors();
      _pendingLinkedProvider = null;
      _pendingOAuthLoginProvider = null;
      _shouldSyncAfterAuthChange = true;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      final providerKey = provider == OAuthProvider.apple
          ? 'apple'
          : provider == OAuthProvider.google
              ? 'google'
              : 'oauth';

      if (_showSignUp) {
        if (user == null) {
          throw Exception(_t('現在のユーザーが見つかりませんでした', 'Current user was not found.'));
        }
        if (!user.isAnonymous) {
          throw Exception(_t(
            'この登録方法は、今使っているデータを引き継いだまま登録するときに利用できます',
            'This sign up method can be used when keeping your current data.',
          ));
        }
        _pendingLinkedProvider = providerKey;
        _pendingOAuthLoginProvider = null;
        await auth.signInWithOAuth(
          provider,
          redirectTo: redirectTo,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        setState(() {
          _infoMessage = _t(
            '認証完了後、自動でデータを同期します。',
            'Your data will sync automatically after authentication.',
          );
        });
      } else {
        _pendingOAuthLoginProvider = providerKey;
        await auth.signInWithOAuth(
          provider,
          redirectTo: redirectTo,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        setState(() {
          _infoMessage = _t(
            'ログイン完了後、自動でデータを同期します。',
            'Your data will sync automatically after log in.',
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _showSignUp
            ? _t('登録に失敗しました', 'Sign up failed.')
            : _t('ログインに失敗しました', 'Log in failed.');
        _isSigningIn = false;
        _shouldSyncAfterAuthChange = false;
        _pendingOAuthLoginProvider = null;
      });
      return;
    }

    Future.delayed(const Duration(seconds: 60), () {
      if (!mounted) return;
      if (attemptId != _oauthAttemptId) return;
      if (!_isSigningIn) return;
      if (_isSyncingAccountData) return;

      setState(() {
        _isSigningIn = false;
        _shouldSyncAfterAuthChange = false;
        _pendingLinkedProvider = null;
        _pendingOAuthLoginProvider = null;
        _infoMessage = null;
        _errorMessage = _t(
          'ログインが完了しませんでした。もう一度お試しください。',
          'Log in was not completed. Please try again.',
        );
      });
    });
  }

  Future<void> _submitWithEmail() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _infoMessage = null;
      _clearFieldErrors();
      _pendingLinkedProvider = null;
      _pendingOAuthLoginProvider = null;
      _shouldSyncAfterAuthChange = false;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;

      var hasError = false;

      if (email.isEmpty) {
        _emailError = _t('メールアドレスを入力してください', 'Enter your email address.');
        hasError = true;
      } else if (!_isValidEmail(email)) {
        _emailError = _t('正しいメールアドレスを入力してください', 'Enter a valid email address.');
        hasError = true;
      }

      if (password.isEmpty) {
        _passwordError = _t('パスワードを入力してください', 'Enter your password.');
        hasError = true;
      } else if (_showSignUp && password.length < 6) {
        _passwordError = _t('パスワードは6文字以上で入力してください', 'Password must be at least 6 characters.');
        hasError = true;
      }

      if (hasError) {
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _shouldSyncAfterAuthChange = false;
        });
        return;
      }

      if (_showSignUp) {
        if (user == null) {
          throw Exception(_t('現在のユーザーが見つかりませんでした', 'Current user was not found.'));
        }
        if (!user.isAnonymous) {
          throw Exception(_t(
            'この登録方法は、今使っているデータを引き継いだまま登録するときに利用できます',
            'This sign up method can be used when keeping your current data.',
          ));
        }
        _pendingLinkedProvider = 'email';
        final hasVerifiedEmail =
            user.email?.toLowerCase() == email.toLowerCase() &&
            user.emailConfirmedAt != null;

        if (!hasVerifiedEmail) {
          await auth.updateUser(
            UserAttributes(
              email: email,
            ),
          );

          // メール確認フローを使わないため、そのまま続行
        }

        await auth.updateUser(
          UserAttributes(
            password: password,
          ),
        );
      } else {
        await auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      await _syncAccountDataIfNeeded();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _shouldSyncAfterAuthChange = false;
        _pendingLinkedProvider = null;
        _pendingOAuthLoginProvider = null;
        final message = e.message.toLowerCase();

        if (_showSignUp) {
          if (message.contains('already') ||
              message.contains('exists') ||
              message.contains('registered')) {
            _emailError = _t('そのメールアドレスはすでに存在しています', 'That email address is already registered.');
          } else {
            _errorMessage = e.message;
          }
        } else {
          if (message.contains('invalid login credentials') ||
              message.contains('invalid_credentials')) {
            _passwordError = _t('パスワードが違います', 'The password is incorrect.');
          } else {
            _errorMessage = e.message;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shouldSyncAfterAuthChange = false;
        _pendingLinkedProvider = null;
        _pendingOAuthLoginProvider = null;
        _errorMessage = _showSignUp ? e.toString() : _t('メールログインに失敗しました', 'Email log in failed.');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final isLoggedIn = !isAnonymous;
    final isBusy = _isSigningIn || _isSyncingAccountData;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showSignUpTab ? _t('アカウント', 'Account') : _t('ログイン', 'Log in')),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAnonymous
                        ? const Color(0xFFFFF4E5)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAnonymous ? Icons.person_outline : Icons.check_circle,
                        color: isAnonymous ? Colors.orange : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAnonymous
                              ? _t('現在はゲスト状態です', 'You are using the app as a guest.')
                              : _t('アカウントにログイン済みです', 'You are logged in.'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: isLoggedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _t('ログイン中です', 'Logged in'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFEDEDED)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Display Apple private relay emails as a friendly label
                                  (() {
                                    final email = user?.email ?? '';
                                    final displayAccount = email.contains('privaterelay.appleid.com')
                                        ? _t('Appleアカウントでログイン中', 'Signed in with Apple')
                                        : (email.isNotEmpty
                                            ? email
                                            : _t('Apple / Google アカウントで利用中', 'Using an Apple / Google account'));
                                    return Text(
                                      displayAccount,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  })(),
                                  const SizedBox(height: 8),
                                  Text(
                                    _t(
                                      'このアカウントでデータを引き継げます。機種変更時も同じアカウントでログインすれば復元できます。',
                                      'Your data is linked to this account. Log in with the same account on a new device to restore it.',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(20),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.logout, size: 36, color: Colors.black87),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      _t('ログアウトしますか？', 'Log out?'),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _t('現在のアカウントからログアウトします', 'You will be logged out of this account.'),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () => Navigator.pop(dialogContext, false),
                                                            style: OutlinedButton.styleFrom(
                                                              foregroundColor: Colors.black45,
                                                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                            ),
                                                            child: Text(_t('キャンセル', 'Cancel')),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () => Navigator.pop(dialogContext, true),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.redAccent,
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                            ),
                                                            child: Text(_t('ログアウト', 'Log out')),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );

                                        if (confirm != true) return;

                                        await Supabase.instance.client.auth.signOut();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(_t('ログアウトしました', 'Logged out.')),
                                          ),
                                        );
                                        setState(() {});
                                      },
                                child: Text(_t('ログアウト', 'Log out')),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud_download_outlined, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  widget.showSignUpTab
                                      ? (_showSignUp ? _t('アカウントを登録', 'Create account') : _t('アカウントにログイン', 'Log in to account'))
                                      : _t('アカウントにログイン', 'Log in to account'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.showSignUpTab
                                  ? (_showSignUp
                                      ? _t(
                                          '登録すると、今のデータを引き継いだまま機種変更時も同じアカウントで使えます。',
                                          'Create an account to keep your current data and use it on a new device later.',
                                        )
                                      : _t(
                                          '登録済みのアカウントでログインすると、保存済みデータをこの端末に同期できます。',
                                          'Log in with your account to sync saved data to this device.',
                                        ))
                                  : _t(
                                      '登録済みのアカウントでログインすると、保存済みデータをこの端末に同期できます。',
                                      'Log in with your account to sync saved data to this device.',
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFEDEDED)),
                              ),
                              child: Text(
                                widget.showSignUpTab
                                    ? (_showSignUp
                                        ? _t(
                                            '新規登録では、今のデータをそのまま引き継いでアカウントを作成します。',
                                            'Sign up keeps your current data and links it to your account.',
                                          )
                                        : _t(
                                            'ログインでは、登録済みアカウントのデータをこの端末へ同期します。',
                                            'Log in to sync your saved account data to this device.',
                                          ))
                                    : _t(
                                        'ログインでは、登録済みアカウントのデータをこの端末へ同期します。',
                                        'Log in to sync your saved account data to this device.',
                                      ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (widget.showSignUpTab) ...[
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showSignUp = true;
                                            _errorMessage = null;
                                            _infoMessage = null;
                                            _clearFieldErrors();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _showSignUp
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _t('新規登録', 'Sign up'),
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: _showSignUp
                                                  ? Colors.black87
                                                  : Colors.black45,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showSignUp = false;
                                            _errorMessage = null;
                                            _infoMessage = null;
                                            _clearFieldErrors();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: !_showSignUp
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _t('ログイン', 'Log in'),
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: !_showSignUp
                                                  ? Colors.black87
                                                  : Colors.black45,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Column(
                              children: [
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: _t('メールアドレス', 'Email'),
                                    border: const OutlineInputBorder(),
                                    errorText: _emailError,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: _t('パスワード', 'Password'),
                                    helperText: _showSignUp ? _t('6文字以上', 'At least 6 characters') : null,
                                    errorText: _passwordError,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isBusy ? null : _submitWithEmail,
                                    child: Text(
                                      widget.showSignUpTab
                                          ? (_showSignUp ? _t('メールで登録', 'Sign up with email') : _t('メールでログイン', 'Log in with email'))
                                          : _t('メールでログイン', 'Log in with email'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        widget.showSignUpTab
                                            ? (_showSignUp
                                                ? _t('または外部アカウントで登録', 'Or sign up with')
                                                : _t('または外部アカウントでログイン', 'Or log in with'))
                                            : _t('または外部アカウントでログイン', 'Or log in with'),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.black45,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: isBusy
                                        ? null
                                        : () => _signInWithProvider(OAuthProvider.apple),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.apple, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.showSignUpTab
                                              ? (_showSignUp ? _t('Appleで登録', 'Sign up with Apple') : _t('Appleでログイン', 'Log in with Apple'))
                                              : _t('Appleでログイン', 'Log in with Apple'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: isBusy
                                        ? null
                                        : () => _signInWithProvider(OAuthProvider.google),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.g_mobiledata, size: 24),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.showSignUpTab
                                              ? (_showSignUp ? _t('Googleで登録', 'Sign up with Google') : _t('Googleでログイン', 'Log in with Google'))
                                              : _t('Googleでログイン', 'Log in with Google'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_infoMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    _infoMessage!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                if (_isSyncingAccountData) ...[
                  const SizedBox(height: 14),
                  Text(
                    _t('ログイン後のデータ同期を行っています…', 'Syncing your data after log in...'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (isBusy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.18),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          _isSyncingAccountData
                              ? _t('データを同期しています...', 'Syncing data...')
                              : (_showSignUp ? _t('処理中です...', 'Processing...') : _t('ログイン中です...', 'Logging in...')),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
