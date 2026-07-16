import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

abstract class Transport {
  Future<void> sendUdp(String data);
  Future<void> sendTcp(String data);
}

class SocketTransport implements Transport {
  final String serverIp;

  SocketTransport(this.serverIp);

  @override
  Future<void> sendUdp(String data) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.send(Uint8List.fromList(data.codeUnits), InternetAddress(serverIp), udpPort);
    socket.close();
  }

  @override
  Future<void> sendTcp(String data) async {
    final socket = await Socket.connect(serverIp, tcpPort, timeout: const Duration(seconds: 2));
    socket.add(data.codeUnits);
    await socket.flush();
    await socket.close();
  }
}

class RemoteTrackpadClient {
  String serverIp = '';
  Transport? transport;

  Transport get _transport {
    if (transport != null) return transport!;
    if (serverIp.isEmpty) throw StateError('Server IP is not set');
    return SocketTransport(serverIp);
  }

  Future<void> sendUdpMove(double dx, double dy) async {
    await _transport.sendUdp(formatUdpMove(dx, dy));
  }

  Future<void> sendUdpScroll(double dx, double dy) async {
    await _transport.sendUdp(formatUdpScroll(dx, dy));
  }

  Future<void> sendTcpCommand(TcpCommand command) async {
    await _transport.sendTcp(formatTcpCommand(command));
  }
}
