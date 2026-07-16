use std::sync::{atomic::{AtomicBool, Ordering}, Arc, Mutex};

use eframe::{egui, NativeOptions};
use tray_icon::{Icon, TrayIcon, TrayIconBuilder, TrayIconEvent};
use local_ip_address::local_ip;

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
    local_ip().map(|ip| ip.to_string()).unwrap_or_else(|_| "127.0.0.1".to_string())
}

pub fn run_ui(config: Arc<Mutex<ServerConfig>>, local_ip: String) -> anyhow::Result<()> {
    let show_window = Arc::new(AtomicBool::new(true));
    let tray_open_flag = Arc::clone(&show_window);

    let icon = Icon::from_rgba(vec![0u8, 0, 0, 255].repeat(16 * 16), 16, 16)
        .map_err(|err| anyhow::anyhow!("tray icon creation failed: {err}"))?;
    let tray_icon = TrayIconBuilder::new()
        .with_tooltip("Remote Trackpad")
        .with_icon(icon)
        .build()
        .map_err(|err| anyhow::anyhow!("tray icon build failed: {err}"))?;

    TrayIconEvent::set_event_handler(Some(move |event| {
        if matches!(event, TrayIconEvent::Click { .. }) {
            tray_open_flag.store(true, Ordering::SeqCst);
        }
    }));

    let app = RemoteTrackpadApp::new(config, local_ip, show_window, tray_icon);
    let mut native_options = NativeOptions::default();
    native_options.viewport = egui::ViewportBuilder::default()
        .with_inner_size(egui::Vec2::new(360.0, 260.0));

    eframe::run_native("Remote Trackpad", native_options, Box::new(|_| Ok(Box::new(app))))
        .map_err(|err| anyhow::anyhow!("eframe failure: {err}"))?;
    Ok(())
}

struct RemoteTrackpadApp {
    config: Arc<Mutex<ServerConfig>>,
    local_ip: String,
    show_window: Arc<AtomicBool>,
    tray_icon: TrayIcon,
    udp_port_input: String,
    tcp_port_input: String,
    sensitivity_input: String,
    restart_required: bool,
}

impl RemoteTrackpadApp {
    fn new(
        config: Arc<Mutex<ServerConfig>>,
        local_ip: String,
        show_window: Arc<AtomicBool>,
        tray_icon: TrayIcon,
    ) -> Self {
        let config_lock = config.lock().unwrap();
        let udp_port_input = config_lock.udp_port.to_string();
        let tcp_port_input = config_lock.tcp_port.to_string();
        let sensitivity_input = config_lock.sensitivity.to_string();
        drop(config_lock);

        Self {
            config,
            local_ip,
            show_window,
            tray_icon,
            udp_port_input,
            tcp_port_input,
            sensitivity_input,
            restart_required: false,
        }
    }
}

impl eframe::App for RemoteTrackpadApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(8.0);
            ui.heading("Remote Trackpad Server");
            ui.label(format!("Local IP: {}", self.local_ip));
            ui.label("Connect the mobile app to the local IP shown above.");
            ui.separator();

            if self.show_window.load(Ordering::SeqCst) {
                ui.label("System tray icon is active. Click the tray icon to reopen this window.");
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
                    if let (Ok(udp_port), Ok(tcp_port), Ok(sensitivity)) = (
                        self.udp_port_input.parse::<u16>(),
                        self.tcp_port_input.parse::<u16>(),
                        self.sensitivity_input.parse::<f32>(),
                    ) {
                        let mut cfg = self.config.lock().unwrap();
                        cfg.udp_port = udp_port;
                        cfg.tcp_port = tcp_port;
                        cfg.sensitivity = sensitivity.clamp(0.1, 10.0);
                        self.restart_required = true;
                    }
                }
                if self.restart_required {
                    ui.colored_label(egui::Color32::YELLOW, "Port changes require a restart to take effect.");
                }
                ui.add_space(8.0);
                if ui.button("Hide Window").clicked() {
                    self.show_window.store(false, Ordering::SeqCst);
                }
            } else {
                ui.label("Tray icon clicked. Open the tray icon again to show the settings window.");
                if ui.button("Show Window").clicked() {
                    self.show_window.store(true, Ordering::SeqCst);
                }
            }
        });
    }
}
