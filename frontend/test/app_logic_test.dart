import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/main.dart';
import 'package:remote_trackpad_frontend/protocol.dart';

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

  test('determines horizontal vs vertical swipe', () {
    expect(isHorizontalSwipe(20.0, 5.0), isTrue);
    expect(isHorizontalSwipe(-20.0, 10.0), isTrue);
    expect(isHorizontalSwipe(5.0, 20.0), isFalse);
    expect(isHorizontalSwipe(-2.0, -15.0), isFalse);
  });

  test('anchor trigger detection', () {
    // stationary anchor + moving finger
    expect(isAnchorTrigger(anchorMovement: 2.0, moverMovement: 18.0), isTrue);
    expect(isAnchorTrigger(anchorMovement: 5.0, moverMovement: 25.0), isTrue);

    // both moving together (regular scroll)
    expect(isAnchorTrigger(anchorMovement: 15.0, moverMovement: 18.0), isFalse);

    // anchor moved too much
    expect(isAnchorTrigger(anchorMovement: 25.0, moverMovement: 50.0), isFalse);
  });

  test('anchor horizontal commands map to Alt-Tab next/prev', () {
    expect(getAnchorHorizontalCommand(15.0), TcpCommand.altTabNext);
    expect(getAnchorHorizontalCommand(-15.0), TcpCommand.altTabPrev);
  });

  test('anchor vertical commands map to Volume Up/Down', () {
    expect(getAnchorVerticalCommand(-10.0), TcpCommand.volumeUp);
    expect(getAnchorVerticalCommand(10.0), TcpCommand.volumeDown);
  });

  test('three-finger horizontal commands map to Alt-Tab next/prev', () {
    expect(getThreeFingerHorizontalCommand(15.0), TcpCommand.altTabNext);
    expect(getThreeFingerHorizontalCommand(-15.0), TcpCommand.altTabPrev);
  });

  test('three-finger vertical commands map to Volume Up/Down', () {
    expect(getThreeFingerVerticalCommand(-10.0), TcpCommand.volumeUp);
    expect(getThreeFingerVerticalCommand(10.0), TcpCommand.volumeDown);
  });

  test('four-finger vertical commands map to minimize/maximize/show_desktop', () {
    expect(getFourFingerVerticalCommand(20.0, 'minimize_active'), TcpCommand.windowMinimize);
    expect(getFourFingerVerticalCommand(-20.0, 'minimize_active'), TcpCommand.windowMaximize);
    expect(getFourFingerVerticalCommand(20.0, 'show_desktop'), TcpCommand.showDesktop);
    expect(getFourFingerVerticalCommand(-20.0, 'show_desktop'), TcpCommand.showDesktop);
  });

  test('four-finger horizontal commands map according to configured action', () {
    // Virtual Desktops
    expect(getFourFingerHorizontalCommand(true, 'virtual_desktops'), TcpCommand.desktopRight);
    expect(getFourFingerHorizontalCommand(false, 'virtual_desktops'), TcpCommand.desktopLeft);

    // Media
    expect(getFourFingerHorizontalCommand(true, 'media'), TcpCommand.mediaNext);
    expect(getFourFingerHorizontalCommand(false, 'media'), TcpCommand.mediaPrev);

    // Browser
    expect(getFourFingerHorizontalCommand(true, 'browser'), TcpCommand.browserForward);
    expect(getFourFingerHorizontalCommand(false, 'browser'), TcpCommand.browserBack);
  });
}
