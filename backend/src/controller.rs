use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::Duration;

use crate::protocol::{parse_tcp_payload, parse_udp_payload, TcpCommand, UdpPacket};
use crate::ui::ServerConfig;
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
    fn press_shift_tab(&mut self);
    fn volume_up(&mut self);
    fn volume_down(&mut self);
    fn window_minimize(&mut self);
    fn window_maximize(&mut self);
    fn show_desktop(&mut self);
    fn desktop_left(&mut self);
    fn desktop_right(&mut self);
    fn media_next(&mut self);
    fn media_prev(&mut self);
    fn browser_back(&mut self);
    fn browser_forward(&mut self);
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
        sleep(Duration::from_millis(10));
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

    fn press_shift_tab(&mut self) {
        let _ = self.enigo.key(Key::Shift, Direction::Press);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::Tab, Direction::Click);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::Shift, Direction::Release);
    }

    fn volume_up(&mut self) {
        let _ = self.enigo.key(Key::VolumeUp, Direction::Click);
    }

    fn volume_down(&mut self) {
        let _ = self.enigo.key(Key::VolumeDown, Direction::Click);
    }

    fn window_minimize(&mut self) {
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::DownArrow, Direction::Click);
        sleep(Duration::from_millis(20));
        let _ = self.enigo.key(Key::DownArrow, Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
    }

    fn window_maximize(&mut self) {
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::UpArrow, Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
    }

    #[cfg(target_os = "windows")]
    fn show_desktop(&mut self) {
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::D, Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
    }

    #[cfg(not(target_os = "windows"))]
    fn show_desktop(&mut self) {
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Unicode('d'), Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
    }

    fn desktop_left(&mut self) {
        let _ = self.enigo.key(Key::Control, Direction::Press);
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::LeftArrow, Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
        let _ = self.enigo.key(Key::Control, Direction::Release);
    }

    fn desktop_right(&mut self) {
        let _ = self.enigo.key(Key::Control, Direction::Press);
        let _ = self.enigo.key(Key::Meta, Direction::Press);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::RightArrow, Direction::Click);
        sleep(Duration::from_millis(15));
        let _ = self.enigo.key(Key::Meta, Direction::Release);
        let _ = self.enigo.key(Key::Control, Direction::Release);
    }

    fn media_next(&mut self) {
        let _ = self.enigo.key(Key::MediaNextTrack, Direction::Click);
    }

    fn media_prev(&mut self) {
        let _ = self.enigo.key(Key::MediaPrevTrack, Direction::Click);
    }

    fn browser_back(&mut self) {
        let _ = self.enigo.key(Key::Alt, Direction::Press);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::LeftArrow, Direction::Click);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::Alt, Direction::Release);
    }

    fn browser_forward(&mut self) {
        let _ = self.enigo.key(Key::Alt, Direction::Press);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::RightArrow, Direction::Click);
        sleep(Duration::from_millis(10));
        let _ = self.enigo.key(Key::Alt, Direction::Release);
    }
}

pub struct AppController<T: InputDevice> {
    device: T,
    alt_tab_active: bool,
    config: Option<Arc<Mutex<ServerConfig>>>,
    accum_dx: f32,
    accum_dy: f32,
}

impl<T: InputDevice> AppController<T> {
    pub fn new(device: T) -> Self {
        Self {
            device,
            alt_tab_active: false,
            config: None,
            accum_dx: 0.0,
            accum_dy: 0.0,
        }
    }

    pub fn with_config(device: T, config: Arc<Mutex<ServerConfig>>) -> Self {
        Self {
            device,
            alt_tab_active: false,
            config: Some(config),
            accum_dx: 0.0,
            accum_dy: 0.0,
        }
    }

    pub fn handle_udp_payload(&mut self, payload: &[u8]) -> anyhow::Result<()> {
        let sensitivity = self
            .config
            .as_ref()
            .and_then(|c| c.lock().ok())
            .map(|c| c.sensitivity)
            .unwrap_or(1.0);

        match parse_udp_payload(payload)? {
            UdpPacket::Move { dx, dy } => {
                self.accum_dx += dx * sensitivity;
                self.accum_dy += dy * sensitivity;

                let move_x = self.accum_dx.trunc();
                let move_y = self.accum_dy.trunc();

                if move_x.abs() >= 1.0 || move_y.abs() >= 1.0 {
                    self.device.move_cursor(move_x, move_y);
                    self.accum_dx -= move_x;
                    self.accum_dy -= move_y;
                }
            }
            UdpPacket::Scroll { dx, dy } => self.device.scroll(dx, dy),
        }
        Ok(())
    }

    pub fn handle_tcp_payload(&mut self, payload: &[u8]) -> anyhow::Result<()> {
        match parse_tcp_payload(payload)? {
            TcpCommand::LeftClick => self.device.left_click(),
            TcpCommand::RightClick => self.device.right_click(),
            TcpCommand::DoubleClick => self.device.double_click(),
            TcpCommand::AltTabStart | TcpCommand::AltTabNext => {
                if !self.alt_tab_active {
                    self.alt_tab_active = true;
                    self.device.press_alt();
                    sleep(Duration::from_millis(15));
                }
                self.device.press_tab();
            }
            TcpCommand::AltTabPrev => {
                if !self.alt_tab_active {
                    self.alt_tab_active = true;
                    self.device.press_alt();
                    sleep(Duration::from_millis(15));
                }
                self.device.press_shift_tab();
            }
            TcpCommand::AltTabEnd => {
                if self.alt_tab_active {
                    self.device.release_alt();
                    self.alt_tab_active = false;
                }
            }
            TcpCommand::VolumeUp => self.device.volume_up(),
            TcpCommand::VolumeDown => self.device.volume_down(),
            TcpCommand::WindowMinimize => self.device.window_minimize(),
            TcpCommand::WindowMaximize => self.device.window_maximize(),
            TcpCommand::ShowDesktop => self.device.show_desktop(),
            TcpCommand::DesktopLeft => self.device.desktop_left(),
            TcpCommand::DesktopRight => self.device.desktop_right(),
            TcpCommand::MediaNext => self.device.media_next(),
            TcpCommand::MediaPrev => self.device.media_prev(),
            TcpCommand::BrowserBack => self.device.browser_back(),
            TcpCommand::BrowserForward => self.device.browser_forward(),
        }
        Ok(())
    }

    pub fn input(&self) -> &T {
        &self.device
    }
}
