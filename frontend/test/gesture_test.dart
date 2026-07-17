import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'pitch-black screen renders and opens settings dialog from hidden zone',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
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

      final state = tester.state(find.byType(RemoteTrackpadApp));
      final dialogFuture = (state as dynamic).showSettingsDialog();
      await tester.pump();

      expect(find.text('Server IP'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await dialogFuture;
    },
  );
}
