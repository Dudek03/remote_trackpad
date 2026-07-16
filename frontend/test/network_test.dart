import 'package:flutter_test/flutter_test.dart';
import 'package:remote_trackpad_frontend/network.dart';
import 'package:remote_trackpad_frontend/protocol.dart';

class MockTransport implements Transport {
  final List<String> udpMessages = [];
  final List<String> tcpMessages = [];

  @override
  Future<void> sendTcp(String data) async {
    tcpMessages.add(data);
  }

  @override
  Future<void> sendUdp(String data) async {
    udpMessages.add(data);
  }
}

void main() {
  test('remote client sends formatted UDP and TCP packets', () async {
    final client = RemoteTrackpadClient();
    client.serverIp = '192.168.0.10';
    final mock = MockTransport();
    client.transport = mock;

    await client.sendUdpMove(5, -2);
    await client.sendUdpScroll(0, 8);
    await client.sendTcpCommand(TcpCommand.leftClick);

    expect(mock.udpMessages, ['M,5.0,-2.0', 'S,0.0,8.0']);
    expect(mock.tcpMessages, ['left_click']);
  });
}
