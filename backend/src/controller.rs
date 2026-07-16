use crate::protocol::{parse_tcp_payload, parse_udp_payload, TcpCommand, UdpPacket};
use enigo::{Axis, Button, Coordinate, Direction, Enigo, Key, Keyboard, Mouse};

pub trait InputDevice {
    fn move_cursor(&mut self, dx: f32, dy: f32);
    fn scroll(&mut self, dx: f32, dy: f32);
    fn left_click(&mut self);
    fn right_click(&mut self);
    fn double_click(&mut self);
    fn press_alt(&mut self);
    fn release_alt(&mut self);
    fn press_tab(&mut self);
    fn volume_up(&mut self);
    fn volume_down(&mut self);
}

pub struct EnigoDevice {
    enigo: Enigo,
}

impl Default for EnigoDevice {
    fn default() -> Self {
        Self {
            enigo: Enigo::new(&enigo::Settings::default()).expect("failed to initialize enigo"),
        }
    }
}

impl InputDevice for EnigoDevice {
    fn move_cursor(&mut self, dx: f32, dy: f32) {
        let _ = self.enigo.move_mouse(dx.round() as i32, dy.round() as i32, Coordinate::Rel);
    }

    fn scroll(&mut self, dx: f32, dy: f32) {
        let dx_i32 = dx.round() as i32;
        let dy_i32 = dy.round() as i32;
        if dx_i32 != 0 {
            let _ = self.enigo.scroll(dx_i32, Axis::Horizontal);
        }
        if dy_i32 != 0 {
            let _ = self.enigo.scroll(dy_i32, Axis::Vertical);
        }
    }

    fn left_click(&mut self) {
        let _ = self.enigo.button(Button::Left, Direction::Click);
    }

    fn right_click(&mut self) {
        let _ = self.enigo.button(Button::Right, Direction::Click);
    }

    fn double_click(&mut self) {
        let _ = self.enigo.button(Button::Left, Direction::Click);
        let _ = self.enigo.button(Button::Left, Direction::Click);
    }

    fn press_alt(&mut self) {
        let _ = self.enigo.key(Key::Alt, Direction::Press);
    }

    fn release_alt(&mut self) {
        let _ = self.enigo.key(Key::Alt, Direction::Release);
    }

    fn press_tab(&mut self) {
        let _ = self.enigo.key(Key::Tab, Direction::Click);
    }

    fn volume_up(&mut self) {
        let _ = self.enigo.key(Key::VolumeUp, Direction::Click);
    }

    fn volume_down(&mut self) {
        let _ = self.enigo.key(Key::VolumeDown, Direction::Click);
    }
}

pub struct AppController<T: InputDevice> {
    device: T,
    alt_tab_active: bool,
}

impl<T: InputDevice> AppController<T> {
    pub fn new(device: T) -> Self {
        Self {
            device,
            alt_tab_active: false,
        }
    }

    pub fn handle_udp_payload(&mut self, payload: &[u8]) -> anyhow::Result<()> {
        match parse_udp_payload(payload)? {
            UdpPacket::Move { dx, dy } => self.device.move_cursor(dx, dy),
            UdpPacket::Scroll { dx, dy } => self.device.scroll(dx, dy),
        }
        Ok(())
    }

    pub fn handle_tcp_payload(&mut self, payload: &[u8]) -> anyhow::Result<()> {
        match parse_tcp_payload(payload)? {
            TcpCommand::LeftClick => self.device.left_click(),
            TcpCommand::RightClick => self.device.right_click(),
            TcpCommand::DoubleClick => self.device.double_click(),
            TcpCommand::AltTabStart => {
                self.alt_tab_active = true;
                self.device.press_alt();
                self.device.press_tab();
            }
            TcpCommand::AltTabEnd => {
                if self.alt_tab_active {
                    self.device.release_alt();
                    self.alt_tab_active = false;
                }
            }
            TcpCommand::VolumeUp => self.device.volume_up(),
            TcpCommand::VolumeDown => self.device.volume_down(),
        }
        Ok(())
    }

    pub fn input(&self) -> &T {
        &self.device
    }
}
