import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';

void main() {
  test('advances tap counts until the settings threshold is reached', () {
    expect(advanceTapCount(0), 1);
    expect(advanceTapCount(2), 3);
  });

  test('opens settings only when the threshold is reached', () {
    expect(shouldOpenSettings(2, 3), isFalse);
    expect(shouldOpenSettings(3, 3), isTrue);
    expect(shouldOpenSettings(4, 3), isTrue);
  });
}
