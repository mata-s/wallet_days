import 'package:flutter/widgets.dart';
import 'app_locale.dart';

class AppText {
  // アプリ名
  static String appTitle(BuildContext context) {
    return AppLocale.isJa(context)
        ? '財布の余命'
        : 'Wallet Days';
  }

  // Welcome説明
  static String welcomeDesc(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'すぐに使い始められます。\nデータのバックアップ・復元には、アカウントが必要です。'
        : 'Start tracking your spending in seconds.\nBackup and restore require an account.';
  }

  // はじめる（タイトル）
  static String startTitle(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'はじめる'
        : 'Get started';
  }

  // はじめる説明
  static String startDesc(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'まずは気軽に始めましょう。'
        : 'Start simple and see how your money flows.';
  }

  // はじめるボタン
  static String startButton(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'はじめる'
        : 'Start';
  }

  // ログインタイトル
  static String loginTitle(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'ログインする'
        : 'Log in';
  }

  // ログイン説明
  static String loginDesc(BuildContext context) {
    return AppLocale.isJa(context)
        ? '以前のデータを引き継ぐ方はこちら。\nApple・Google・メールでログインできます。'
        : 'Already have data?\nLog in with Apple, Google, or email to continue.';
  }

  // ログインボタン
  static String loginButton(BuildContext context) {
    return AppLocale.isJa(context)
        ? 'ログインする'
        : 'Log in';
  }
}