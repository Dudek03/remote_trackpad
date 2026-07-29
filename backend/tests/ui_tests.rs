use std::sync::{Arc, Mutex};

use remote_trackpad_backend::ui::{apply_server_config, get_local_ip, is_tray_click, parse_config_inputs, sanitize_sensitivity, ServerConfig};
use tray_icon::{dpi::PhysicalPosition, MouseButton, MouseButtonState, Rect, TrayIconEvent, TrayIconId};

#[test]
fn parses_server_config_inputs_with_sanitized_sensitivity() {
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

#[test]
fn local_ip_returns_a_non_empty_string() {
    let ip = get_local_ip();
    assert!(!ip.is_empty());
}

#[test]
fn tray_click_event_is_detected() {
    let event = TrayIconEvent::Click {
        id: TrayIconId::new("test"),
        position: PhysicalPosition::new(0.0, 0.0),
        rect: Rect::default(),
        button: MouseButton::Left,
        button_state: MouseButtonState::Down,
    };
    assert!(is_tray_click(&event));
}
