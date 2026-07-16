import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';

void main() {
  testWidgets('pitch-black screen renders and opens settings dialog from hidden zone', (tester) async {
    await tester.pumpWidget(const RemoteTrackpadApp());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);

    final hiddenZone = find.byKey(const Key('hidden-settings-zone'));
    expect(hiddenZone, findsOneWidget);

    await tester.tap(hiddenZone);
    await tester.tap(hiddenZone);
    await tester.tap(hiddenZone);
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('Server IP'), findsOneWidget);
  });
}
