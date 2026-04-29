import 'package:flutter/widgets.dart';

class AppLocale {
  static String current(BuildContext context) {
    final locale = Localizations.localeOf(context);

    if (locale.languageCode == 'ja') {
      return 'ja';
    }
    return 'en';
  }

  static bool isJa(BuildContext context) {
    return current(context) == 'ja';
  }

  static bool isEn(BuildContext context) {
    return current(context) == 'en';
  }
}