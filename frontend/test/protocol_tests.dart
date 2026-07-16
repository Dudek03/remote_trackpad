import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/protocol.dart';

void main() {
  test('formats UDP and TCP payloads correctly', () {
    expect(formatUdpMove(12, -3), 'M,12.0,-3.0');
    expect(formatUdpScroll(0, 5), 'S,0.0,5.0');
    expect(formatTcpCommand(TcpCommand.leftClick), 'left_click');
    expect(formatTcpCommand(TcpCommand.altTabStart), 'alt_tab_start');
  });
}
