use remote_trackpad_backend::controller::{AppController, InputDevice};
use remote_trackpad_backend::protocol::{parse_tcp_payload, parse_udp_payload, TcpCommand, UdpPacket};

#[derive(Default)]
struct MockInputDevice {
    cursor_dx: i32,
    cursor_dy: i32,
    scroll_dx: i32,
    scroll_dy: i32,
    left_clicks: usize,
    right_clicks: usize,
    double_clicks: usize,
    alt_pressed: bool,
    tab_pressed: bool,
    volume_up: usize,
    volume_down: usize,
}

impl InputDevice for MockInputDevice {
    fn move_cursor(&mut self, dx: f32, dy: f32) {
        self.cursor_dx += dx.round() as i32;
        self.cursor_dy += dy.round() as i32;
    }

    fn scroll(&mut self, dx: f32, dy: f32) {
        self.scroll_dx += dx.round() as i32;
        self.scroll_dy += dy.round() as i32;
    }

    fn left_click(&mut self) {
        self.left_clicks += 1;
    }

    fn right_click(&mut self) {
        self.right_clicks += 1;
    }

    fn double_click(&mut self) {
        self.double_clicks += 1;
    }

    fn press_alt(&mut self) {
        self.alt_pressed = true;
    }

    fn release_alt(&mut self) {
        self.alt_pressed = false;
    }

    fn press_tab(&mut self) {
        self.tab_pressed = true;
    }

    fn volume_up(&mut self) {
        self.volume_up += 1;
    }

    fn volume_down(&mut self) {
        self.volume_down += 1;
    }
}

#[test]
fn parses_udp_move_and_scroll_packets() {
    let move_packet = parse_udp_payload(b"M,14.5,-6.2").unwrap();
    assert_eq!(move_packet, UdpPacket::Move { dx: 14.5, dy: -6.2 });

    let scroll_packet = parse_udp_payload(b"S,3.0,20.0").unwrap();
    assert_eq!(scroll_packet, UdpPacket::Scroll { dx: 3.0, dy: 20.0 });
}

#[test]
fn parses_tcp_commands() {
    assert_eq!(parse_tcp_payload(b"left_click").unwrap(), TcpCommand::LeftClick);
    assert_eq!(parse_tcp_payload(b"right_click").unwrap(), TcpCommand::RightClick);
    assert_eq!(parse_tcp_payload(b"alt_tab_start").unwrap(), TcpCommand::AltTabStart);
    assert_eq!(parse_tcp_payload(b"volume_up").unwrap(), TcpCommand::VolumeUp);
}

#[test]
fn maps_gestures_to_input_actions() {
    let mut controller = AppController::new(MockInputDevice::default());
    controller.handle_udp_payload(b"M,10,12").unwrap();
    controller.handle_udp_payload(b"S,1,4").unwrap();
    controller.handle_tcp_payload(b"left_click").unwrap();
    controller.handle_tcp_payload(b"alt_tab_start").unwrap();
    controller.handle_tcp_payload(b"alt_tab_end").unwrap();
    controller.handle_tcp_payload(b"volume_up").unwrap();

    let device = controller.input();
    assert_eq!(device.cursor_dx, 10);
    assert_eq!(device.cursor_dy, 12);
    assert_eq!(device.scroll_dx, 1);
    assert_eq!(device.scroll_dy, 4);
    assert_eq!(device.left_clicks, 1);
    assert!(!device.alt_pressed);
    assert_eq!(device.volume_up, 1);
}
