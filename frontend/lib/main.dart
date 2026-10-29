import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'network.dart';
import 'protocol.dart';

const int hiddenSettingsTapThreshold = 3;
const Duration hiddenSettingsTapResetDuration = Duration(milliseconds: 1000);

int advanceTapCount(int tapCount) => tapCount + 1;

bool shouldOpenSettings(int tapCount, int threshold) => tapCount >= threshold;

bool isHorizontalSwipe(double dx, double dy) => dx.abs() >= dy.abs();

TcpCommand getThreeFingerHorizontalCommand(double dx) =>
    dx > 0 ? TcpCommand.altTabNext : TcpCommand.altTabPrev;

TcpCommand getThreeFingerVerticalCommand(double dy) =>
    dy <= 0 ? TcpCommand.volumeUp : TcpCommand.volumeDown;

TcpCommand getFourFingerVerticalCommand(double dy, String action) {
  if (action == 'show_desktop') {
    return TcpCommand.showDesktop;
  }
  return dy > 0 ? TcpCommand.windowMinimize : TcpCommand.windowMaximize;
}

TcpCommand getFourFingerHorizontalCommand(bool isRight, String action) {
  switch (action) {
    case 'media':
      return isRight ? TcpCommand.mediaNext : TcpCommand.mediaPrev;
    case 'browser':
      return isRight ? TcpCommand.browserForward : TcpCommand.browserBack;
    case 'virtual_desktops':
    default:
      return isRight ? TcpCommand.desktopRight : TcpCommand.desktopLeft;
  }
}

class RemoteTrackpadApp extends StatefulWidget {
  const RemoteTrackpadApp({super.key});

  @override
  State<RemoteTrackpadApp> createState() => _RemoteTrackpadAppState();
}

class _RemoteTrackpadAppState extends State<RemoteTrackpadApp> {
  String _serverIp = '';
  String _fourFingerHorizontalAction = 'virtual_desktops';
  String _fourFingerVerticalAction = 'minimize_active';
  int _tapCount = 0;
  Timer? _tapResetTimer;
  final _activePointers = <int>{};
  bool _altTabActive = false;
  bool _threeFingerGestureLocked = false;
  bool _threeFingerIsHorizontal = false;
  double _threeFingerDeltaX = 0.0;
  double _threeFingerDeltaY = 0.0;
  bool _fourFingerTriggered = false;
  double _fourFingerDeltaX = 0.0;
  double _fourFingerDeltaY = 0.0;
  final _client = RemoteTrackpadClient();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _client.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('server_ip') ?? '';
      _fourFingerHorizontalAction =
          prefs.getString('four_finger_horizontal') ?? 'virtual_desktops';
      _fourFingerVerticalAction =
          prefs.getString('four_finger_vertical') ?? 'minimize_active';
      _client.serverIp = _serverIp;
    });
  }

  Future<void> _saveSettings({
    required String ip,
    required String fourFingerHorizontal,
    required String fourFingerVertical,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('four_finger_horizontal', fourFingerHorizontal);
    await prefs.setString('four_finger_vertical', fourFingerVertical);
    setState(() {
      _serverIp = ip;
      _fourFingerHorizontalAction = fourFingerHorizontal;
      _fourFingerVerticalAction = fourFingerVertical;
      _client.serverIp = ip;
    });
  }

  Future<void> _saveServerIp(String value) => _saveSettings(
        ip: value,
        fourFingerHorizontal: _fourFingerHorizontalAction,
        fourFingerVertical: _fourFingerVerticalAction,
      );

  void _handleHiddenZoneTap() {
    final nextTapCount = advanceTapCount(_tapCount);
    _tapCount = nextTapCount;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(hiddenSettingsTapResetDuration, () {
      if (mounted) {
        setState(() {
          _tapCount = 0;
        });
      }
    });

    if (shouldOpenSettings(_tapCount, hiddenSettingsTapThreshold)) {
      _tapResetTimer?.cancel();
      setState(() {
        _tapCount = 0;
      });
      showSettingsDialog();
    }
  }

  Future<void> showSettingsDialog() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) return;
    final ipController = TextEditingController(text: _serverIp);
    String selectedHorizontal = _fourFingerHorizontalAction;
    String selectedVertical = _fourFingerVerticalAction;

    await showDialog<void>(
      context: dialogContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Server IP',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ipController,
                      decoration:
                          const InputDecoration(hintText: 'e.g. 192.168.1.10'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Text('Gesty 4 palcami w boki',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedHorizontal,
                      items: const [
                        DropdownMenuItem(
                          value: 'virtual_desktops',
                          child: Text('Pulpity wirtualne (Ctrl+Win+←/→)'),
                        ),
                        DropdownMenuItem(
                          value: 'media',
                          child: Text('Muzyka (Poprzedni / Następny)'),
                        ),
                        DropdownMenuItem(
                          value: 'browser',
                          child: Text('Przeglądarka (Wstecz / Dalej)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedHorizontal = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Gesty 4 palcami góra/dół',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedVertical,
                      items: const [
                        DropdownMenuItem(
                          value: 'minimize_active',
                          child: Text('Minimalizuj / Maksymalizuj (Win+↓/↑)'),
                        ),
                        DropdownMenuItem(
                          value: 'show_desktop',
                          child: Text('Pokaż pulpit (Win+D)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedVertical = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    _saveSettings(
                      ip: ipController.text.trim(),
                      fourFingerHorizontal: selectedHorizontal,
                      fourFingerVertical: selectedVertical,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
      _threeFingerGestureLocked = false;
      _threeFingerIsHorizontal = false;
      _threeFingerDeltaX = 0.0;
      _threeFingerDeltaY = 0.0;
    } else if (_activePointers.length == 4) {
      _fourFingerTriggered = false;
      _fourFingerDeltaX = 0.0;
      _fourFingerDeltaY = 0.0;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final count = _activePointers.length;
    if (count == 1) {
      _sendUdpMove(event.delta.dx, event.delta.dy);
    } else if (count == 2) {
      if (_activePointers.isNotEmpty && event.pointer == _activePointers.first) {
        if (event.delta.dy.abs() >= 0.5) {
          _sendUdpScroll(0, event.delta.dy);
        }
      }
    } else if (count == 3) {
      if (_activePointers.isNotEmpty && event.pointer == _activePointers.first) {
        if (!_threeFingerGestureLocked) {
          _threeFingerDeltaX += event.delta.dx;
          _threeFingerDeltaY += event.delta.dy;

          const threshold = 12.0;
          if (_threeFingerDeltaX.abs() >= threshold ||
              _threeFingerDeltaY.abs() >= threshold) {
            _threeFingerGestureLocked = true;
            if (isHorizontalSwipe(_threeFingerDeltaX, _threeFingerDeltaY)) {
              _threeFingerIsHorizontal = true;
              _altTabActive = true;
              _sendTcpCommand(
                  getThreeFingerHorizontalCommand(_threeFingerDeltaX));
              _threeFingerDeltaX = 0.0;
            } else {
              _threeFingerIsHorizontal = false;
              _sendTcpCommand(getThreeFingerVerticalCommand(_threeFingerDeltaY));
              _threeFingerDeltaY = 0.0;
            }
          }
        } else {
          if (_threeFingerIsHorizontal) {
            _threeFingerDeltaX += event.delta.dx;
            const step = 25.0;
            if (_threeFingerDeltaX >= step) {
              _sendTcpCommand(TcpCommand.altTabNext);
              _threeFingerDeltaX = 0.0;
            } else if (_threeFingerDeltaX <= -step) {
              _sendTcpCommand(TcpCommand.altTabPrev);
              _threeFingerDeltaX = 0.0;
            }
          } else {
            _threeFingerDeltaY += event.delta.dy;
            const step = 15.0;
            if (_threeFingerDeltaY <= -step) {
              _sendTcpCommand(TcpCommand.volumeUp);
              _threeFingerDeltaY = 0.0;
            } else if (_threeFingerDeltaY >= step) {
              _sendTcpCommand(TcpCommand.volumeDown);
              _threeFingerDeltaY = 0.0;
            }
          }
        }
      }
    } else if (count == 4) {
      if (_activePointers.isNotEmpty && event.pointer == _activePointers.first) {
        if (!_fourFingerTriggered) {
          _fourFingerDeltaX += event.delta.dx;
          _fourFingerDeltaY += event.delta.dy;

          const threshold = 16.0;
          if (_fourFingerDeltaX.abs() >= threshold ||
              _fourFingerDeltaY.abs() >= threshold) {
            _fourFingerTriggered = true;
            if (!isHorizontalSwipe(_fourFingerDeltaX, _fourFingerDeltaY)) {
              _sendTcpCommand(getFourFingerVerticalCommand(
                  _fourFingerDeltaY, _fourFingerVerticalAction));
            } else {
              _sendTcpCommand(getFourFingerHorizontalCommand(
                  _fourFingerDeltaX > 0, _fourFingerHorizontalAction));
            }
          }
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _checkGestureEnd();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _checkGestureEnd();
  }

  void _checkGestureEnd() {
    if (_altTabActive && _activePointers.length < 3) {
      _sendTcpCommand(TcpCommand.altTabEnd);
      _altTabActive = false;
    }
    if (_activePointers.length < 3) {
      _threeFingerGestureLocked = false;
      _threeFingerDeltaX = 0.0;
      _threeFingerDeltaY = 0.0;
    }
    if (_activePointers.length < 4) {
      _fourFingerTriggered = false;
      _fourFingerDeltaX = 0.0;
      _fourFingerDeltaY = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _sendTcpCommand(TcpCommand.leftClick),
                  onDoubleTap: () => _sendTcpCommand(TcpCommand.rightClick),
                  child: Center(
                    child: Text(
                      _serverIp.isEmpty
                          ? 'Connect to a server'
                          : 'Connected to $_serverIp',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton(
                    key: const Key('hidden-settings-zone'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size(96, 48),
                    ),
                    onPressed: _handleHiddenZoneTap,
                    child: const Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(const RemoteTrackpadApp());
}
