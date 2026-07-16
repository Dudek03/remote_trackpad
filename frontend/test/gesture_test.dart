import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';

// Increase test window size so the hidden zone is on-screen and tappable.

void main() {
  testWidgets('pitch-black screen renders and opens settings dialog from hidden zone', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized() as TestWidgetsFlutterBinding;
    binding.window.physicalSizeTestValue = const Size(800, 600);
    binding.window.devicePixelRatioTestValue = 1.0;

    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const RemoteTrackpadApp());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);

    final hiddenZone = find.byKey(const Key('hidden-settings-zone'));
    expect(hiddenZone, findsOneWidget);

    // Three quick taps in the hidden zone should open the settings dialog.
    await tester.tap(hiddenZone, warnIfMissed: false);
    await tester.pump();
    await tester.tap(hiddenZone, warnIfMissed: false);
    await tester.pump();
    await tester.tap(hiddenZone, warnIfMissed: false);
    // Allow animations and dialog presentation to settle.
    await tester.pumpAndSettle();

    expect(find.text('Server IP'), findsOneWidget);
  });
}
