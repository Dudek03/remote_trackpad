use std::{sync::{Arc, Mutex}, time::Duration};

use tokio::{io::AsyncReadExt, net::{TcpListener, UdpSocket}, time::sleep};

use crate::{controller::{AppController, EnigoDevice}, ui::ServerConfig};

pub async fn run_server(
    config: Arc<Mutex<ServerConfig>>,
    mut shutdown_rx: tokio::sync::watch::Receiver<bool>,
) -> anyhow::Result<()> {
    let (udp_port, tcp_port) = {
        let config_lock = config.lock().unwrap();
        (config_lock.udp_port, config_lock.tcp_port)
    };

    let udp_socket = UdpSocket::bind(("0.0.0.0", udp_port)).await?;
    let tcp_listener = TcpListener::bind(("0.0.0.0", tcp_port)).await?;

    println!("[SERVER] Started UDP on port {udp_port}, TCP on port {tcp_port}");

    let controller = Arc::new(Mutex::new(AppController::with_config(
        EnigoDevice::default(),
        Arc::clone(&config),
    )));

    let udp_controller = Arc::clone(&controller);
    tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        loop {
            match udp_socket.recv_from(&mut buf).await {
                Ok((len, _)) => {
                    let _ = udp_controller.lock().unwrap().handle_udp_payload(&buf[..len]);
                }
                Err(err) => {
                    eprintln!("[UDP] error: {err}");
                    sleep(Duration::from_millis(50)).await;
                }
            }
        }
    });

    let tcp_controller = Arc::clone(&controller);
    tokio::spawn(async move {
        loop {
            match tcp_listener.accept().await {
                Ok((mut stream, addr)) => {
                    println!("[TCP] Client connected from {addr}");
                    let ctrl = Arc::clone(&tcp_controller);
                    tokio::spawn(async move {
                        let mut buf = [0u8; 1024];
                        while let Ok(len) = stream.read(&mut buf).await {
                            if len == 0 {
                                break;
                            }
                            let text = match std::str::from_utf8(&buf[..len]) {
                                Ok(t) => t,
                                Err(_) => continue,
                            };
                            for line in text.lines() {
                                let trimmed = line.trim();
                                if !trimmed.is_empty() {
                                    println!("[TCP] Received command: '{trimmed}'");
                                    match ctrl.lock().unwrap().handle_tcp_payload(trimmed.as_bytes()) {
                                        Ok(_) => println!("[TCP] Executed successfully: '{trimmed}'"),
                                        Err(err) => eprintln!("[TCP] Execution error for '{trimmed}': {err:?}"),
                                    }
                                }
                            }
                        }
                        println!("[TCP] Client disconnected: {addr}");
                    });
                }
                Err(err) => {
                    eprintln!("[TCP] listener error: {err}");
                    sleep(Duration::from_millis(50)).await;
                }
            }
        }
    });

    tokio::select! {
        _ = tokio::signal::ctrl_c() => {},
        _ = shutdown_rx.wait_for(|&s| s) => {},
    }
    Ok(())
}
