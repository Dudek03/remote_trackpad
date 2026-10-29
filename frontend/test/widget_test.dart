// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the connect screen and hidden settings zone', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RemoteTrackpadApp());
    await tester.pumpAndSettle();

    expect(find.text('Connect to a server'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('hidden-settings-zone')), findsOneWidget);
  });

  test('advanceTapCount increments the tap counter', () {
    expect(advanceTapCount(0), 1);
    expect(advanceTapCount(4), 5);
  });

  test('shouldOpenSettings is true at threshold or above', () {
    expect(shouldOpenSettings(2, 3), isFalse);
    expect(shouldOpenSettings(3, 3), isTrue);
    expect(shouldOpenSettings(5, 3), isTrue);
  });
}
