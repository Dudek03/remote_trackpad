import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'network.dart';
import 'protocol.dart';

class RemoteTrackpadApp extends StatefulWidget {
  const RemoteTrackpadApp({super.key});

  @override
  State<RemoteTrackpadApp> createState() => _RemoteTrackpadAppState();
}

class _RemoteTrackpadAppState extends State<RemoteTrackpadApp> {
  String _serverIp = '';
  int _tapCount = 0;
  Timer? _tapResetTimer;
  final _activePointers = <int>{};
  bool _altTabActive = false;
  final _client = RemoteTrackpadClient();

  @override
  void initState() {
    super.initState();
    _loadServerIp();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('server_ip') ?? '';
      _client.serverIp = _serverIp;
      _client.transport = null;
    });
  }

  Future<void> _saveServerIp(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', value);
    setState(() {
      _serverIp = value;
      _client.serverIp = value;
      _client.transport = null;
    });
  }

  void _handleHiddenZoneTap() {
    _tapCount += 1;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        _tapCount = 0;
      });
    });

    if (_tapCount >= 3) {
      _tapResetTimer?.cancel();
      setState(() {
        _tapCount = 0;
      });
      _showSettingsDialog();
    }
  }

  Future<void> _showSettingsDialog() async {
    final controller = TextEditingController(text: _serverIp);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Server IP'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'e.g. 192.168.1.10'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _saveServerIp(controller.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendUdpMove(double dx, double dy) async {
    if (_serverIp.isEmpty) return;
    await _client.sendUdpMove(dx, dy);
  }

  Future<void> _sendUdpScroll(double dx, double dy) async {
    if (_serverIp.isEmpty) return;
    await _client.sendUdpScroll(dx, dy);
  }

  Future<void> _sendTcpCommand(TcpCommand command) async {
    if (_serverIp.isEmpty) return;
    await _client.sendTcpCommand(command);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length == 3) {
      _altTabActive = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final count = _activePointers.length;
    if (count == 1) {
      _sendUdpMove(event.delta.dx, event.delta.dy);
    } else if (count == 2) {
      if (event.delta.dy.abs() >= 1.0) {
        _sendUdpScroll(0, event.delta.dy);
      }
    } else if (count == 3) {
      if (!_altTabActive && event.delta.dx.abs() > 8.0) {
        _altTabActive = true;
        _sendTcpCommand(TcpCommand.altTabStart);
      }
    } else if (count == 4) {
      if (event.delta.dy <= -8.0) {
        _sendTcpCommand(TcpCommand.volumeUp);
      } else if (event.delta.dy >= 8.0) {
        _sendTcpCommand(TcpCommand.volumeDown);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_altTabActive && _activePointers.length < 3) {
      _sendTcpCommand(TcpCommand.altTabEnd);
      _altTabActive = false;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_altTabActive && _activePointers.length < 3) {
      _sendTcpCommand(TcpCommand.altTabEnd);
      _altTabActive = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _sendTcpCommand(TcpCommand.leftClick),
            onDoubleTap: () => _sendTcpCommand(TcpCommand.rightClick),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _serverIp.isEmpty ? 'Connect to a server' : 'Connected to $_serverIp',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: const Key('hidden-settings-zone'),
                    onTap: _handleHiddenZoneTap,
                    child: const SizedBox(width: 90, height: 90),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(const RemoteTrackpadApp());
}
