enum TcpCommand {
  leftClick,
  rightClick,
  doubleClick,
  altTabStart,
  altTabEnd,
  volumeUp,
  volumeDown,
}

String formatUdpMove(double dx, double dy) => 'M,${dx.toStringAsFixed(1)},${dy.toStringAsFixed(1)}';
String formatUdpScroll(double dx, double dy) => 'S,${dx.toStringAsFixed(1)},${dy.toStringAsFixed(1)}';

String formatTcpCommand(TcpCommand command) {
  switch (command) {
    case TcpCommand.leftClick:
      return 'left_click';
    case TcpCommand.rightClick:
      return 'right_click';
    case TcpCommand.doubleClick:
      return 'double_click';
    case TcpCommand.altTabStart:
      return 'alt_tab_start';
    case TcpCommand.altTabEnd:
      return 'alt_tab_end';
    case TcpCommand.volumeUp:
      return 'volume_up';
    case TcpCommand.volumeDown:
      return 'volume_down';
  }
}

const udpPort = 8001;
const tcpPort = 8002;
