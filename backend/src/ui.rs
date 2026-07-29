use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

use eframe::{egui, NativeOptions};
use local_ip_address::local_ip;
use tray_icon::{Icon, TrayIcon, TrayIconBuilder, TrayIconEvent};

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

fn set_window_visibility(ctx: &egui::Context, visible: bool) {
    let command = if visible {
        egui::ViewportCommand::Visible(true)
    } else {
        egui::ViewportCommand::Visible(false)
    };
    ctx.send_viewport_cmd(command);
}

pub fn run_ui(config: Arc<Mutex<ServerConfig>>, local_ip: String) -> anyhow::Result<()> {
    let show_window = Arc::new(AtomicBool::new(false));
    let tray_open_flag = Arc::clone(&show_window);

    let icon = Icon::from_rgba(vec![0u8, 0, 0, 255].repeat(16 * 16), 16, 16)
        .map_err(|err| anyhow::anyhow!("tray icon creation failed: {err}"))?;
    let tray_icon = TrayIconBuilder::new()
        .with_tooltip("Remote Trackpad")
        .with_icon(icon)
        .build()
        .map_err(|err| anyhow::anyhow!("tray icon build failed: {err}"))?;

    TrayIconEvent::set_event_handler(Some(move |event| {
        if is_tray_click(&event) {
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
    #[allow(dead_code)]
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
        let window_visible = self.show_window.load(Ordering::SeqCst);
        set_window_visibility(ctx, window_visible);

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(8.0);
            ui.heading("Remote Trackpad Server");
            ui.label(format!("Local IP: {}", self.local_ip));
            ui.label("Connect the mobile app to the local IP shown above.");
            ui.separator();

            if window_visible {
                ui.label("System tray icon is active. Clicking the tray icon brings this window back when needed.");
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
                    ui.colored_label(egui::Color32::YELLOW, "Port changes require a restart to take effect.");
                }
                ui.add_space(8.0);
                if ui.button("Hide Window").clicked() {
                    self.show_window.store(false, Ordering::SeqCst);
                }
            } else {
                ui.label("The settings UI stays hidden until you click the tray icon.");
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_config_inputs_with_sanitized_sensitivity() {
        let parsed = parse_config_inputs("8001", "8002", "1.25").unwrap();
        assert_eq!(parsed, (8001, 8002, 1.25));
    }

    #[test]
    fn clamps_sensitivity_to_the_supported_range() {
        assert_eq!(sanitize_sensitivity(0.0), 0.1);
        assert_eq!(sanitize_sensitivity(20.0), 10.0);
        assert_eq!(sanitize_sensitivity(2.0), 2.0);
    }

    #[test]
    fn applies_server_settings_to_the_shared_config() {
        let config = Arc::new(Mutex::new(ServerConfig::default()));
        let applied = apply_server_config(&config, "9001", "9002", "3.5");

        assert!(applied);
        let cfg = config.lock().unwrap();
        assert_eq!(cfg.udp_port, 9001);
        assert_eq!(cfg.tcp_port, 9002);
        assert_eq!(cfg.sensitivity, 3.5);
    }
}
