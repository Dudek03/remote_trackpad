import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/protocol.dart';

void main() {
  test('formats UDP and TCP payloads correctly', () {
    expect(formatUdpMove(12, -3), 'M,12.0,-3.0');
    expect(formatUdpScroll(0, 5), 'S,0.0,5.0');
    expect(formatTcpCommand(TcpCommand.leftClick), 'left_click');
    expect(formatTcpCommand(TcpCommand.rightClick), 'right_click');
    expect(formatTcpCommand(TcpCommand.doubleClick), 'double_click');
    expect(formatTcpCommand(TcpCommand.altTabStart), 'alt_tab_start');
    expect(formatTcpCommand(TcpCommand.altTabEnd), 'alt_tab_end');
    expect(formatTcpCommand(TcpCommand.altTabNext), 'alt_tab_next');
    expect(formatTcpCommand(TcpCommand.altTabPrev), 'alt_tab_prev');
    expect(formatTcpCommand(TcpCommand.volumeUp), 'volume_up');
    expect(formatTcpCommand(TcpCommand.volumeDown), 'volume_down');
    expect(formatTcpCommand(TcpCommand.windowMinimize), 'window_minimize');
    expect(formatTcpCommand(TcpCommand.windowMaximize), 'window_maximize');
    expect(formatTcpCommand(TcpCommand.showDesktop), 'show_desktop');
    expect(formatTcpCommand(TcpCommand.desktopLeft), 'desktop_left');
    expect(formatTcpCommand(TcpCommand.desktopRight), 'desktop_right');
    expect(formatTcpCommand(TcpCommand.mediaNext), 'media_next');
    expect(formatTcpCommand(TcpCommand.mediaPrev), 'media_prev');
    expect(formatTcpCommand(TcpCommand.browserBack), 'browser_back');
    expect(formatTcpCommand(TcpCommand.browserForward), 'browser_forward');
  });
}
