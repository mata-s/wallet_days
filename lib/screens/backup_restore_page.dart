import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saiyome/screens/home_page.dart';
import 'package:saiyome/services/account_data_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isSigningIn = false;
  bool _isSyncingAccountData = false;
  late bool _showSignUp;
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  String? _infoMessage;
  String? _emailError;
  String? _passwordError;

  String? _errorMessage;
  String? _pendingLinkedProvider;
  bool _shouldSyncAfterAuthChange = false;


  @override
  void initState() {
    super.initState();
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
    }

    await _syncAccountDataIfNeeded();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            'データを同期しました（支出${result.expenseCount}件・履歴${result.historyCount}件）',
          ),
        ),
      );
      if (_pendingLinkedProvider != null) {
        await _markAccountLinked(_pendingLinkedProvider!);
        _pendingLinkedProvider = null;
      }

      if (!widget.showSignUpTab) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _showSignUp ? '登録後のデータ同期に失敗しました' : 'ログイン後のデータ同期に失敗しました';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSyncingAccountData = false;
        _isSigningIn = false;
        _shouldSyncAfterAuthChange = false;
      });
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _infoMessage = null;
      _clearFieldErrors();
      _pendingLinkedProvider = null;
      _shouldSyncAfterAuthChange = true;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;

      if (_showSignUp) {
        if (user == null) {
          throw Exception('現在のユーザーが見つかりませんでした');
        }
        if (!user.isAnonymous) {
          throw Exception('この登録方法は、今使っているデータを引き継いだまま登録するときに利用できます');
        }
        _pendingLinkedProvider = provider == OAuthProvider.apple
            ? 'apple'
            : provider == OAuthProvider.google
                ? 'google'
                : 'oauth';
        await auth.linkIdentity(provider);
        if (!mounted) return;
        setState(() {
          _infoMessage = '認証完了後、自動でデータを同期します。';
        });
      } else {
        await auth.signInWithOAuth(provider);
        if (!mounted) return;
        setState(() {
          _infoMessage = 'ログイン完了後、自動でデータを同期します。';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _showSignUp ? '登録に失敗しました' : 'ログインに失敗しました';
        _isSigningIn = false;
        _shouldSyncAfterAuthChange = false;
      });
      return;
    }
  }

  Future<void> _submitWithEmail() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _infoMessage = null;
      _clearFieldErrors();
      _pendingLinkedProvider = null;
      _shouldSyncAfterAuthChange = false;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;

      var hasError = false;

      if (email.isEmpty) {
        _emailError = 'メールアドレスを入力してください';
        hasError = true;
      } else if (!_isValidEmail(email)) {
        _emailError = '正しいメールアドレスを入力してください';
        hasError = true;
      }

      if (password.isEmpty) {
        _passwordError = 'パスワードを入力してください';
        hasError = true;
      } else if (_showSignUp && password.length < 6) {
        _passwordError = 'パスワードは6文字以上で入力してください';
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
          throw Exception('現在のユーザーが見つかりませんでした');
        }
        if (!user.isAnonymous) {
          throw Exception('この登録方法は、今使っているデータを引き継いだまま登録するときに利用できます');
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
        final message = e.message.toLowerCase();

        if (_showSignUp) {
          if (message.contains('already') ||
              message.contains('exists') ||
              message.contains('registered')) {
            _emailError = 'そのメールアドレスはすでに存在しています';
          } else {
            _errorMessage = e.message;
          }
        } else {
          if (message.contains('invalid login credentials') ||
              message.contains('invalid_credentials')) {
            _passwordError = 'パスワードが違います';
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
        _errorMessage = _showSignUp ? e.toString() : 'メールログインに失敗しました';
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
    final isBusy = _isSigningIn || _isSyncingAccountData;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showSignUpTab ? 'アカウント' : 'ログイン'),
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
                              ? '現在はゲスト状態です（この端末のみに保存されます）'
                              : 'アカウントにログイン済みです',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_download_outlined, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            widget.showSignUpTab
                                ? (_showSignUp ? 'アカウントを登録' : 'アカウントにログイン')
                                : 'アカウントにログイン',
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
                                ? '登録すると、今のデータを引き継いだまま機種変更時も同じアカウントで使えます。'
                                : '登録済みのアカウントでログインすると、保存済みデータをこの端末に同期できます。')
                            : '登録済みのアカウントでログインすると、保存済みデータをこの端末に同期できます。',
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
                                  ? '新規登録では、今のデータをそのまま引き継いでアカウントを作成します。'
                                  : 'ログインでは、登録済みアカウントのデータをこの端末へ同期します。')
                              : 'ログインでは、登録済みアカウントのデータをこの端末へ同期します。',
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
                                      '新規登録',
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
                                      'ログイン',
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
                              labelText: 'メールアドレス',
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
                              labelText: 'パスワード',
                              helperText: _showSignUp ? '6文字以上' : null,
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
                                    ? (_showSignUp ? 'メールで登録' : 'メールでログイン')
                                    : 'メールでログイン',
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
                                          ? 'または外部アカウントで登録'
                                          : 'または外部アカウントでログイン')
                                      : 'または外部アカウントでログイン',
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
                                        ? (_showSignUp ? 'Appleで登録' : 'Appleでログイン')
                                        : 'Appleでログイン',
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
                                        ? (_showSignUp ? 'Googleで登録' : 'Googleでログイン')
                                        : 'Googleでログイン',
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
                    'ログイン後のデータ同期を行っています…',
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
                              ? 'データを同期しています...'
                              : (_showSignUp ? '処理中です...' : 'ログイン中です...'),
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
