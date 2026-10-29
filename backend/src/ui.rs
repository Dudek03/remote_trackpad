use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

use eframe::{egui, NativeOptions};
use local_ip_address::local_ip;
use tray_icon::{
    menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem},
    Icon, TrayIcon, TrayIconBuilder, TrayIconEvent,
};

#[cfg(target_os = "windows")]
mod win32 {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;
    use std::sync::atomic::{AtomicIsize, Ordering};

    pub type HWND = isize;
    pub type BOOL = i32;
    pub type UINT = u32;
    pub type WPARAM = usize;
    pub type LPARAM = isize;

    pub const SW_HIDE: i32 = 0;
    pub const SW_RESTORE: i32 = 9;
    pub const WM_CLOSE: UINT = 0x0010;

    #[link(name = "user32")]
    extern "system" {
        pub fn FindWindowW(lpClassName: *const u16, lpWindowName: *const u16) -> HWND;
        pub fn ShowWindow(hwnd: HWND, nCmdShow: i32) -> BOOL;
        pub fn SetForegroundWindow(hwnd: HWND) -> BOOL;
        pub fn PostMessageW(hwnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) -> BOOL;
        pub fn GetWindowThreadProcessId(hwnd: HWND, lpdwProcessId: *mut u32) -> u32;
    }

    static CACHED_HWND: AtomicIsize = AtomicIsize::new(0);

    fn to_wide(s: &str) -> Vec<u16> {
        OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
    }

    pub fn get_main_hwnd() -> HWND {
        let cached = CACHED_HWND.load(Ordering::SeqCst);
        if cached != 0 {
            return cached;
        }

        let title = to_wide("Remote Trackpad");
        let hwnd = unsafe { FindWindowW(std::ptr::null(), title.as_ptr()) };
        if hwnd != 0 {
            let current_pid = std::process::id();
            let mut window_pid = 0u32;
            unsafe {
                GetWindowThreadProcessId(hwnd, &mut window_pid);
            }
            if window_pid == current_pid {
                CACHED_HWND.store(hwnd, Ordering::SeqCst);
                return hwnd;
            }
        }
        hwnd
    }

    pub fn restore_window() {
        let hwnd = get_main_hwnd();
        if hwnd != 0 {
            unsafe {
                ShowWindow(hwnd, SW_RESTORE);
                SetForegroundWindow(hwnd);
            }
        }
    }

    pub fn hide_window() {
        let hwnd = get_main_hwnd();
        if hwnd != 0 {
            unsafe {
                ShowWindow(hwnd, SW_HIDE);
            }
        }
    }

    pub fn close_window() {
        let hwnd = get_main_hwnd();
        if hwnd != 0 {
            unsafe {
                PostMessageW(hwnd, WM_CLOSE, 0, 0);
            }
        }
    }
}

#[derive(Debug, Clone)]
pub struct ServerConfig {
    pub udp_port: u16,
    pub tcp_port: u16,
    pub sensitivity: f32,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            udp_port: 8001,
            tcp_port: 8002,
            sensitivity: 1.0,
        }
    }
}

pub fn get_local_ip() -> String {
    local_ip()
        .map(|ip| ip.to_string())
        .unwrap_or_else(|_| "127.0.0.1".to_string())
}

pub fn parse_config_inputs(
    udp_port_input: &str,
    tcp_port_input: &str,
    sensitivity_input: &str,
) -> Option<(u16, u16, f32)> {
    let udp_port = udp_port_input.parse::<u16>().ok()?;
    let tcp_port = tcp_port_input.parse::<u16>().ok()?;
    let sensitivity = sanitize_sensitivity(sensitivity_input.parse::<f32>().ok()?);
    Some((udp_port, tcp_port, sensitivity))
}

pub fn is_tray_click(event: &TrayIconEvent) -> bool {
    matches!(event, TrayIconEvent::Click { .. })
}

pub fn sanitize_sensitivity(sensitivity: f32) -> f32 {
    sensitivity.clamp(0.1, 10.0)
}

pub fn apply_server_config(
    config: &Arc<Mutex<ServerConfig>>,
    udp_port_input: &str,
    tcp_port_input: &str,
    sensitivity_input: &str,
) -> bool {
    let Some((udp_port, tcp_port, sensitivity)) = parse_config_inputs(
        udp_port_input,
        tcp_port_input,
        sensitivity_input,
    ) else {
        return false;
    };

    let mut cfg = config.lock().unwrap();
    cfg.udp_port = udp_port;
    cfg.tcp_port = tcp_port;
    cfg.sensitivity = sensitivity;
    true
}

pub fn run_ui(config: Arc<Mutex<ServerConfig>>, local_ip: String) -> anyhow::Result<()> {
    let mut native_options = NativeOptions::default();
    native_options.viewport = egui::ViewportBuilder::default()
        .with_inner_size(egui::Vec2::new(360.0, 300.0))
        .with_close_button(true);

    let app_config = Arc::clone(&config);
    let app_ip = local_ip.clone();

    eframe::run_native(
        "Remote Trackpad",
        native_options,
        Box::new(move |cc| {
            let app = RemoteTrackpadApp::new(app_config, app_ip, cc.egui_ctx.clone());
            Ok(Box::new(app))
        }),
    )
    .map_err(|err| anyhow::anyhow!("eframe failure: {err}"))?;
    Ok(())
}

struct RemoteTrackpadApp {
    config: Arc<Mutex<ServerConfig>>,
    local_ip: String,
    show_window: Arc<AtomicBool>,
    should_exit: Arc<AtomicBool>,
    _tray_icon: Option<TrayIcon>,
    _tray_menu: Menu,
    _ip_item: MenuItem,
    _open_item: MenuItem,
    _exit_item: MenuItem,
    udp_port_input: String,
    tcp_port_input: String,
    sensitivity_input: String,
    restart_required: bool,
}

impl RemoteTrackpadApp {
    fn new(
        config: Arc<Mutex<ServerConfig>>,
        local_ip: String,
        egui_ctx: egui::Context,
    ) -> Self {
        let config_lock = config.lock().unwrap();
        let udp_port_input = config_lock.udp_port.to_string();
        let tcp_port_input = config_lock.tcp_port.to_string();
        let sensitivity_input = config_lock.sensitivity.to_string();
        drop(config_lock);

        let show_window = Arc::new(AtomicBool::new(true));
        let should_exit = Arc::new(AtomicBool::new(false));

        // Create tray context menu
        let tray_menu = Menu::new();
        let ip_item = MenuItem::with_id("ip_info", format!("IP: {local_ip}"), false, None);
        let open_item = MenuItem::with_id("open_window", "Otwórz edytor", true, None);
        let sep = PredefinedMenuItem::separator();
        let exit_item = MenuItem::with_id("exit_app", "Zamknij serwer", true, None);

        let _ = tray_menu.append(&ip_item);
        let _ = tray_menu.append(&sep);
        let _ = tray_menu.append(&open_item);
        let _ = tray_menu.append(&exit_item);

        let menu_box = Box::new(tray_menu.clone());

        let tray_icon = Icon::from_rgba(vec![0u8, 0, 0, 255].repeat(16 * 16), 16, 16)
            .ok()
            .and_then(|icon| {
                TrayIconBuilder::new()
                    .with_tooltip("Remote Trackpad")
                    .with_icon(icon)
                    .with_menu(menu_box)
                    .build()
                    .map_err(|err| eprintln!("System tray unavailable: {err}"))
                    .ok()
            });

        let show_flag = Arc::clone(&show_window);
        let exit_flag = Arc::clone(&should_exit);
        let ctx_menu = egui_ctx.clone();

        MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
            match event.id.as_ref() {
                "open_window" => {
                    show_flag.store(true, Ordering::SeqCst);
                    #[cfg(target_os = "windows")]
                    win32::restore_window();
                    ctx_menu.request_repaint();
                }
                "exit_app" => {
                    exit_flag.store(true, Ordering::SeqCst);
                    #[cfg(target_os = "windows")]
                    win32::close_window();
                    ctx_menu.request_repaint();
                    std::thread::spawn(|| {
                        std::thread::sleep(std::time::Duration::from_millis(200));
                        std::process::exit(0);
                    });
                }
                _ => {}
            }
        }));

        let show_flag_tray = Arc::clone(&show_window);
        let ctx_tray = egui_ctx;
        TrayIconEvent::set_event_handler(Some(move |event: TrayIconEvent| {
            if is_tray_click(&event) {
                show_flag_tray.store(true, Ordering::SeqCst);
                #[cfg(target_os = "windows")]
                win32::restore_window();
                ctx_tray.request_repaint();
            }
        }));

        Self {
            config,
            local_ip,
            show_window,
            should_exit,
            _tray_icon: tray_icon,
            _tray_menu: tray_menu,
            _ip_item: ip_item,
            _open_item: open_item,
            _exit_item: exit_item,
            udp_port_input,
            tcp_port_input,
            sensitivity_input,
            restart_required: false,
        }
    }
}

impl eframe::App for RemoteTrackpadApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // If exit was requested, terminate cleanly
        if self.should_exit.load(Ordering::SeqCst) {
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            return;
        }

        // Intercept 'X' window close button to minimize/hide rather than exit process
        if ctx.input(|i| i.viewport().close_requested()) {
            if self.should_exit.load(Ordering::SeqCst) {
                return;
            } else {
                ctx.send_viewport_cmd(egui::ViewportCommand::CancelClose);
                self.show_window.store(false, Ordering::SeqCst);
                #[cfg(target_os = "windows")]
                win32::hide_window();
            }
        }

        let is_visible = self.show_window.load(Ordering::SeqCst);
        if !is_visible {
            return;
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(8.0);
            ui.heading("Remote Trackpad Server");
            ui.label(format!("Local IP: {}", self.local_ip));
            ui.label("Connect the mobile app to the local IP shown above.");
            ui.separator();

            if self._tray_icon.is_some() {
                ui.label("System tray icon is active. Closing this window minimizes it to tray.");
            } else {
                ui.label("System tray unavailable; window controls active.");
            }
            ui.add_space(8.0);
            ui.horizontal(|ui| {
                ui.label("UDP Port:");
                ui.text_edit_singleline(&mut self.udp_port_input);
            });
            ui.horizontal(|ui| {
                ui.label("TCP Port:");
                ui.text_edit_singleline(&mut self.tcp_port_input);
            });
            ui.horizontal(|ui| {
                ui.label("Sensitivity:");
                ui.text_edit_singleline(&mut self.sensitivity_input);
            });
            ui.add_space(8.0);
            if ui.button("Apply Settings").clicked() {
                if apply_server_config(
                    &self.config,
                    &self.udp_port_input,
                    &self.tcp_port_input,
                    &self.sensitivity_input,
                ) {
                    self.restart_required = true;
                }
            }
            if self.restart_required {
                ui.colored_label(
                    egui::Color32::YELLOW,
                    "Port changes require a restart to take effect.",
                );
            }
            ui.add_space(12.0);
            ui.separator();
            ui.horizontal(|ui| {
                if ui.button("Zminimalizuj do traya").clicked() {
                    self.show_window.store(false, Ordering::SeqCst);
                    #[cfg(target_os = "windows")]
                    win32::hide_window();
                }
                if ui.button("Zamknij serwer").clicked() {
                    self.should_exit.store(true, Ordering::SeqCst);
                    ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                }
            });
        });
    }
}
