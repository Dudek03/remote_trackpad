import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

abstract class Transport {
  Future<void> sendUdp(String data);
  Future<void> sendTcp(String data);
}

class SocketTransport implements Transport {
  final String serverIp;
  RawDatagramSocket? _udpSocket;
  Socket? _tcpSocket;
  bool _isDisposed = false;
  Future<void>? _tcpConnecting;

  SocketTransport(this.serverIp);

  Future<RawDatagramSocket?> _getUdpSocket() async {
    if (_isDisposed) return null;
    if (_udpSocket == null) {
      try {
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      } catch (_) {
        return null;
      }
    }
    return _udpSocket;
  }

  @override
  Future<void> sendUdp(String data) async {
    if (_isDisposed || serverIp.isEmpty) return;
    final socket = await _getUdpSocket();
    if (socket != null) {
      try {
        socket.send(Uint8List.fromList(data.codeUnits), InternetAddress(serverIp), udpPort);
      } catch (_) {}
    }
  }

  Future<Socket?> _getTcpSocket() async {
    if (_isDisposed || serverIp.isEmpty) return null;
    if (_tcpSocket != null) return _tcpSocket;
    if (_tcpConnecting != null) {
      await _tcpConnecting;
      return _tcpSocket;
    }

    final completer = Completer<void>();
    _tcpConnecting = completer.future;
    try {
      final s = await Socket.connect(serverIp, tcpPort, timeout: const Duration(seconds: 2));
      _tcpSocket = s;
      s.listen(
        (_) {},
        onError: (_) {
          _tcpSocket?.destroy();
          _tcpSocket = null;
        },
        onDone: () {
          _tcpSocket = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _tcpSocket = null;
    } finally {
      completer.complete();
      _tcpConnecting = null;
    }
    return _tcpSocket;
  }

  @override
  Future<void> sendTcp(String data) async {
    if (_isDisposed || serverIp.isEmpty) return;
    final socket = await _getTcpSocket();
    if (socket != null) {
      try {
        socket.write('$data\n');
        await socket.flush();
        return;
      } catch (_) {
        _tcpSocket?.destroy();
        _tcpSocket = null;
      }
    }

    // Fallback: one-shot connection if persistent connection fails
    try {
      final fallback = await Socket.connect(serverIp, tcpPort, timeout: const Duration(seconds: 2));
      fallback.write('$data\n');
      await fallback.flush();
      await fallback.close();
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    _udpSocket?.close();
    _udpSocket = null;
    _tcpSocket?.destroy();
    _tcpSocket = null;
  }
}

class RemoteTrackpadClient {
  String _serverIp = '';
  Transport? transport;

  String get serverIp => _serverIp;
  set serverIp(String value) {
    if (_serverIp != value) {
      _serverIp = value;
      final t = transport;
      if (t is SocketTransport) {
        t.dispose();
      }
      transport = null;
    }
  }

  Transport get _transport {
    if (transport != null) return transport!;
    if (_serverIp.isEmpty) throw StateError('Server IP is not set');
    transport = SocketTransport(_serverIp);
    return transport!;
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

  void dispose() {
    final t = transport;
    if (t is SocketTransport) {
      t.dispose();
    }
  }
}
