import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'network.dart';
import 'protocol.dart';

const int hiddenSettingsTapThreshold = 3;
const Duration hiddenSettingsTapResetDuration = Duration(milliseconds: 1000);

int advanceTapCount(int tapCount) => tapCount + 1;

bool shouldOpenSettings(int tapCount, int threshold) => tapCount >= threshold;

bool isHorizontalSwipe(double dx, double dy) => dx.abs() >= dy.abs();

bool isAnchorTrigger({
  required double anchorMovement,
  required double moverMovement,
}) {
  return anchorMovement <= 25.0 && (moverMovement - anchorMovement) >= 12.0;
}

TcpCommand getAnchorHorizontalCommand(double dx) =>
    dx > 0 ? TcpCommand.altTabNext : TcpCommand.altTabPrev;

TcpCommand getAnchorVerticalCommand(double dy) =>
    dy <= 0 ? TcpCommand.volumeUp : TcpCommand.volumeDown;

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

  // Multi-touch tracking
  final _activePointers = <int, Offset>{};
  final _pointerDownPos = <int, Offset>{};
  final _twoPointerBaselines = <int, Offset>{};
  int _maxPointersInSession = 0;

  // Anchor (kotwica: 1 hold + 1 move) gesture state
  bool _anchorGestureLocked = false;
  int? _anchorPointerId;
  int? _moverPointerId;
  bool _anchorIsHorizontal = false;
  double _anchorStepAccumX = 0.0;
  double _anchorStepAccumY = 0.0;
  bool _scrollGestureLocked = false;

  // 3-finger gesture state (fallback)
  bool _threeFingerGestureLocked = false;
  bool _threeFingerIsHorizontal = false;
  double _gestureDeltaX = 0.0;
  double _gestureDeltaY = 0.0;

  // 4-finger gesture state
  bool _fourFingerTriggered = false;

  // Alt-Tab state
  bool _altTabActive = false;

  // HUD & feedback
  String _hudMessage = '';
  Timer? _hudResetTimer;

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
    _hudResetTimer?.cancel();
    _client.dispose();
    super.dispose();
  }

  void _triggerHaptic({bool isStrong = false}) {
    try {
      if (isStrong) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  void _setHudMessage(String msg) {
    _hudResetTimer?.cancel();
    setState(() {
      _hudMessage = msg;
    });
    _hudResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _hudMessage = '';
        });
      }
    });
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
                    const SizedBox(height: 20),
                    const Divider(),
                    const Text('Ściąga z gestów:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    const Text(
                      '• 1 palec: Mysz (ruch, tap = LPM, 2x tap = PPM)\n'
                      '• 2 palce: Przewijanie (Scroll)\n'
                      '• Kotwica (1 palec przytrzymaj + 2. przesuń):\n'
                      '    ↔ w boki: Alt + Tab (wybór okna)\n'
                      '    ↕ góra / dół: Głośność\n'
                      '• 4 palce: Zarządzanie oknami i pulpitami',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
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
    _activePointers[event.pointer] = event.position;
    _pointerDownPos[event.pointer] = event.position;

    if (_activePointers.length > _maxPointersInSession) {
      _maxPointersInSession = _activePointers.length;
    }

    if (_activePointers.length == 2) {
      // Establish baseline positions for the 2-pointer interaction
      _twoPointerBaselines.clear();
      for (final entry in _activePointers.entries) {
        _twoPointerBaselines[entry.key] = entry.value;
      }
      _anchorGestureLocked = false;
      _scrollGestureLocked = false;
      _anchorPointerId = null;
      _moverPointerId = null;
    }

    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length > _maxPointersInSession) {
      _maxPointersInSession = _activePointers.length;
    }

    if (_maxPointersInSession >= 4) {
      // 4-finger gestures
      final pointerCount = _activePointers.length.clamp(1, 4);
      _gestureDeltaX += event.delta.dx / pointerCount;
      _gestureDeltaY += event.delta.dy / pointerCount;

      if (!_fourFingerTriggered) {
        const threshold = 12.0;
        if (_gestureDeltaX.abs() >= threshold ||
            _gestureDeltaY.abs() >= threshold) {
          _fourFingerTriggered = true;
          _triggerHaptic(isStrong: true);

          if (!isHorizontalSwipe(_gestureDeltaX, _gestureDeltaY)) {
            final cmd = getFourFingerVerticalCommand(
                _gestureDeltaY, _fourFingerVerticalAction);
            _sendTcpCommand(cmd);
            _setHudMessage(_gestureDeltaY > 0
                ? '4 palce: Minimalizacja'
                : '4 palce: Maksymalizacja');
          } else {
            final isRight = _gestureDeltaX > 0;
            final cmd = getFourFingerHorizontalCommand(
                isRight, _fourFingerHorizontalAction);
            _sendTcpCommand(cmd);
            _setHudMessage(
                '4 palce: ${isRight ? 'Pulpit w prawo' : 'Pulpit w lewo'}');
          }
        }
      }
    } else if (_maxPointersInSession == 3) {
      // 3-finger gestures (fallback)
      final pointerCount = _activePointers.length.clamp(1, 3);
      _gestureDeltaX += event.delta.dx / pointerCount;
      _gestureDeltaY += event.delta.dy / pointerCount;

      if (!_threeFingerGestureLocked) {
        const threshold = 10.0;
        if (_gestureDeltaX.abs() >= threshold ||
            _gestureDeltaY.abs() >= threshold) {
          _threeFingerGestureLocked = true;
          _triggerHaptic();

          if (isHorizontalSwipe(_gestureDeltaX, _gestureDeltaY)) {
            _threeFingerIsHorizontal = true;
            _altTabActive = true;
            final cmd = getThreeFingerHorizontalCommand(_gestureDeltaX);
            _sendTcpCommand(cmd);
            _setHudMessage(
                '3 palce: Alt+Tab ${_gestureDeltaX > 0 ? 'Dalej' : 'Wstecz'}');
            _gestureDeltaX = 0.0;
          } else {
            _threeFingerIsHorizontal = false;
            final cmd = getThreeFingerVerticalCommand(_gestureDeltaY);
            _sendTcpCommand(cmd);
            _setHudMessage(
                '3 palce: ${_gestureDeltaY <= 0 ? 'Głośniej +' : 'Ciszej -'}');
            _gestureDeltaY = 0.0;
          }
        }
      } else {
        if (_threeFingerIsHorizontal) {
          const step = 20.0;
          if (_gestureDeltaX >= step) {
            _sendTcpCommand(TcpCommand.altTabNext);
            _triggerHaptic();
            _setHudMessage('3 palce: Alt+Tab Dalej');
            _gestureDeltaX = 0.0;
          } else if (_gestureDeltaX <= -step) {
            _sendTcpCommand(TcpCommand.altTabPrev);
            _triggerHaptic();
            _setHudMessage('3 palce: Alt+Tab Wstecz');
            _gestureDeltaX = 0.0;
          }
        } else {
          const step = 12.0;
          if (_gestureDeltaY <= -step) {
            _sendTcpCommand(TcpCommand.volumeUp);
            _triggerHaptic();
            _setHudMessage('3 palce: Głośniej +');
            _gestureDeltaY = 0.0;
          } else if (_gestureDeltaY >= step) {
            _sendTcpCommand(TcpCommand.volumeDown);
            _triggerHaptic();
            _setHudMessage('3 palce: Ciszej -');
            _gestureDeltaY = 0.0;
          }
        }
      }
    } else if (_maxPointersInSession == 2 && _activePointers.length == 2) {
      // 2-finger: Anchor gesture OR Scroll
      final keys = _activePointers.keys.toList();
      final id1 = keys[0];
      final id2 = keys[1];

      final base1 = _twoPointerBaselines[id1] ?? _activePointers[id1]!;
      final base2 = _twoPointerBaselines[id2] ?? _activePointers[id2]!;

      // Euclidean displacement from the moment 2 pointers were active
      final dist1 = (_activePointers[id1]! - base1).distance;
      final dist2 = (_activePointers[id2]! - base2).distance;

      if (!_anchorGestureLocked && !_scrollGestureLocked) {
        int? anchorId;
        int? moverId;

        if (isAnchorTrigger(anchorMovement: dist1, moverMovement: dist2)) {
          anchorId = id1;
          moverId = id2;
        } else if (isAnchorTrigger(anchorMovement: dist2, moverMovement: dist1)) {
          anchorId = id2;
          moverId = id1;
        }

        if (anchorId != null && moverId != null) {
          _anchorGestureLocked = true;
          _anchorPointerId = anchorId;
          _moverPointerId = moverId;

          final moverBase = _twoPointerBaselines[moverId] ?? _activePointers[moverId]!;
          final moverCur = _activePointers[moverId]!;
          final totalDelta = moverCur - moverBase;

          _triggerHaptic();

          if (isHorizontalSwipe(totalDelta.dx, totalDelta.dy)) {
            _anchorIsHorizontal = true;
            _altTabActive = true;
            final cmd = getAnchorHorizontalCommand(totalDelta.dx);
            _sendTcpCommand(cmd);
            _setHudMessage(
                'Kotwica: Alt+Tab ${totalDelta.dx > 0 ? 'Dalej' : 'Wstecz'}');
            _anchorStepAccumX = 0.0;
          } else {
            _anchorIsHorizontal = false;
            final cmd = getAnchorVerticalCommand(totalDelta.dy);
            _sendTcpCommand(cmd);
            _setHudMessage(
                'Kotwica: ${totalDelta.dy <= 0 ? 'Głośniej +' : 'Ciszej -'}');
            _anchorStepAccumY = 0.0;
          }
        } else if (dist1 >= 15.0 && dist2 >= 15.0) {
          _scrollGestureLocked = true;
        }
      }

      if (_anchorGestureLocked) {
        if (event.pointer == _moverPointerId) {
          if (_anchorIsHorizontal) {
            _anchorStepAccumX += event.delta.dx;
            const step = 20.0;
            if (_anchorStepAccumX >= step) {
              _sendTcpCommand(TcpCommand.altTabNext);
              _triggerHaptic();
              _setHudMessage('Kotwica: Alt+Tab Dalej');
              _anchorStepAccumX = 0.0;
            } else if (_anchorStepAccumX <= -step) {
              _sendTcpCommand(TcpCommand.altTabPrev);
              _triggerHaptic();
              _setHudMessage('Kotwica: Alt+Tab Wstecz');
              _anchorStepAccumX = 0.0;
            }
          } else {
            _anchorStepAccumY += event.delta.dy;
            const step = 14.0;
            if (_anchorStepAccumY <= -step) {
              _sendTcpCommand(TcpCommand.volumeUp);
              _triggerHaptic();
              _setHudMessage('Kotwica: Głośniej +');
              _anchorStepAccumY = 0.0;
            } else if (_anchorStepAccumY >= step) {
              _sendTcpCommand(TcpCommand.volumeDown);
              _triggerHaptic();
              _setHudMessage('Kotwica: Ciszej -');
              _anchorStepAccumY = 0.0;
            }
          }
        }
      } else if (_scrollGestureLocked) {
        if (event.pointer == _activePointers.keys.first) {
          if (event.delta.dy.abs() >= 0.5) {
            _sendUdpScroll(0, event.delta.dy);
          }
        }
      }
    } else if (_maxPointersInSession == 1) {
      // 1-finger move
      _sendUdpMove(event.delta.dx, event.delta.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _checkGestureEnd();
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _checkGestureEnd();
    setState(() {});
  }

  void _checkGestureEnd() {
    if (_altTabActive && _activePointers.length < 2) {
      _sendTcpCommand(TcpCommand.altTabEnd);
      _altTabActive = false;
    }

    if (_activePointers.length < 2) {
      _anchorGestureLocked = false;
      _anchorPointerId = null;
      _moverPointerId = null;
      _anchorStepAccumX = 0.0;
      _anchorStepAccumY = 0.0;
      _scrollGestureLocked = false;
      _twoPointerBaselines.clear();
    }

    if (_activePointers.isEmpty) {
      _maxPointersInSession = 0;
      _pointerDownPos.clear();
      _threeFingerGestureLocked = false;
      _threeFingerIsHorizontal = false;
      _fourFingerTriggered = false;
      _gestureDeltaX = 0.0;
      _gestureDeltaY = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTouches = _activePointers.length;

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
                  onTap: () {
                    // Only click if it was purely a 1-finger interaction
                    if (_maxPointersInSession <= 1) {
                      _sendTcpCommand(TcpCommand.leftClick);
                    }
                  },
                  onDoubleTap: () {
                    if (_maxPointersInSession <= 1) {
                      _sendTcpCommand(TcpCommand.rightClick);
                    }
                  },
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _serverIp.isEmpty
                                    ? 'Connect to a server'
                                    : 'Connected to $_serverIp',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 12),
                              const Text(
                                '📋 Ściąga z gestów:\n'
                                '• 1 palec: Mysz (ruch, tap = LPM, 2x tap = PPM)\n'
                                '• 2 palce: Przewijanie (Scroll)\n'
                                '• ⚓ Kotwica (trzymaj 1 palec + ruch 2.):\n'
                                '    ↔ w boki: Alt + Tab (wybór okna)\n'
                                '    ↕ góra/dół: Głośność komputera\n'
                                '• 4 palce: Minimalizacja / Pulpity',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                        if (_hudMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blueAccent),
                            ),
                            child: Text(
                              _hudMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Pointer count indicator at top
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: activeTouches > 0 ? 0.9 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dotknięć: $activeTouches',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
              // Help button in bottom-left
              Positioned(
                left: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white12,
                      minimumSize: const Size(96, 48),
                    ),
                    onPressed: showSettingsDialog,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Gesty / IP'),
                  ),
                ),
              ),
              // Hidden settings zone button in bottom-right (3 taps)
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
