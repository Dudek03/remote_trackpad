enum TcpCommand {
  leftClick,
  rightClick,
  doubleClick,
  altTabStart,
  altTabEnd,
  altTabNext,
  altTabPrev,
  volumeUp,
  volumeDown,
  windowMinimize,
  windowMaximize,
  showDesktop,
  desktopLeft,
  desktopRight,
  mediaNext,
  mediaPrev,
  browserBack,
  browserForward,
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
    case TcpCommand.altTabNext:
      return 'alt_tab_next';
    case TcpCommand.altTabPrev:
      return 'alt_tab_prev';
    case TcpCommand.volumeUp:
      return 'volume_up';
    case TcpCommand.volumeDown:
      return 'volume_down';
    case TcpCommand.windowMinimize:
      return 'window_minimize';
    case TcpCommand.windowMaximize:
      return 'window_maximize';
    case TcpCommand.showDesktop:
      return 'show_desktop';
    case TcpCommand.desktopLeft:
      return 'desktop_left';
    case TcpCommand.desktopRight:
      return 'desktop_right';
    case TcpCommand.mediaNext:
      return 'media_next';
    case TcpCommand.mediaPrev:
      return 'media_prev';
    case TcpCommand.browserBack:
      return 'browser_back';
    case TcpCommand.browserForward:
      return 'browser_forward';
  }
}

const udpPort = 8001;
const tcpPort = 8002;
