import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:just_installer_workspace/main.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'just_installer_workspace',
      packageName: 'com.justunknown.justinstallerworkspace',
      version: '1.1.0',
      buildNumber: '2',
      buildSignature: '',
    );
  });

  testWidgets('Showcase page renders title and check-for-update button', (WidgetTester tester) async {
    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Just Installer Workspace'), findsOneWidget);
    expect(find.byIcon(Icons.system_update), findsOneWidget);
  });
}
