import 'package:flutter/material.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';

class PasswordCategories {
  static const String all = 'All';
  static const String general = 'General';
  static const String social = 'Social';
  static const String work = 'Work';
  static const String finance = 'Finance';
  static const String shopping = 'Shopping';
  static const String other = 'Other';

  static const List<String> filterCategories = [
    all,
    general,
    social,
    work,
    finance,
    shopping,
    other,
  ];

  static const List<String> entryCategories = [
    general,
    social,
    work,
    finance,
    shopping,
    other,
  ];

  static String labelFor(AppLocalizations loc, String category) {
    switch (category) {
      case all:
        return loc.categoryAll;
      case general:
        return loc.categoryGeneral;
      case social:
        return loc.categorySocial;
      case work:
        return loc.categoryWork;
      case finance:
        return loc.categoryFinance;
      case shopping:
        return loc.categoryShopping;
      case other:
        return loc.categoryOther;
      default:
        return category;
    }
  }

  static IconData iconFor(String category) {
    switch (category) {
      case social:
        return Icons.public;
      case work:
        return Icons.work;
      case finance:
        return Icons.account_balance_wallet;
      case shopping:
        return Icons.shopping_bag;
      default:
        return Icons.lock_outline;
    }
  }
}
