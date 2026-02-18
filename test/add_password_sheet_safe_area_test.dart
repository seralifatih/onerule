import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/widgets/add_password_sheet.dart';

Widget _buildSheetHost(
    {required EdgeInsets padding, required EdgeInsets viewInsets}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      padding: padding,
      viewInsets: viewInsets,
    ),
    child: const Scaffold(
      body: AddPasswordSheet(),
    ),
  );
}

void main() {
  testWidgets('CTA stays above bottom safe area when keyboard is closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildSheetHost(
          padding: const EdgeInsets.only(bottom: 34),
          viewInsets: EdgeInsets.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ctaBottom = tester.getBottomLeft(find.text('SAVE')).dy;
    expect(ctaBottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('CTA moves above keyboard when keyboard is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildSheetHost(
          padding: const EdgeInsets.only(bottom: 34),
          viewInsets: const EdgeInsets.only(bottom: 280),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ctaBottom = tester.getBottomLeft(find.text('SAVE')).dy;
    expect(ctaBottom, lessThanOrEqualTo(844 - 280));
  });
}
