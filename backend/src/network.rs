use std::{sync::{Arc, Mutex}, time::Duration};

use tokio::{io::AsyncReadExt, net::{TcpListener, UdpSocket}, time::sleep};

use crate::{controller::{AppController, EnigoDevice}, ui::ServerConfig};

pub async fn run_server(config: Arc<Mutex<ServerConfig>>) -> anyhow::Result<()> {
    let config_lock = config.lock().unwrap();
    let udp_socket = UdpSocket::bind(("0.0.0.0", config_lock.udp_port)).await?;
    let tcp_listener = TcpListener::bind(("0.0.0.0", config_lock.tcp_port)).await?;
    drop(config_lock);

    let controller = Arc::new(Mutex::new(AppController::new(EnigoDevice::default())));
    let udp_controller = controller.clone();

    tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        loop {
            match udp_socket.recv_from(&mut buf).await {
                Ok((len, _)) => {
                    let _ = udp_controller.lock().unwrap().handle_udp_payload(&buf[..len]);
                }
                Err(err) => {
                    eprintln!("udp error: {err}");
                    sleep(Duration::from_millis(50)).await;
                }
            }
        }
    });

    let tcp_controller = controller.clone();
    tokio::spawn(async move {
        loop {
            match tcp_listener.accept().await {
                Ok((mut stream, _)) => {
                    let mut buf = [0u8; 1024];
                    if let Ok(len) = stream.read(&mut buf).await {
                        let _ = tcp_controller.lock().unwrap().handle_tcp_payload(&buf[..len]);
                    }
                }
                Err(err) => {
                    eprintln!("tcp error: {err}");
                    sleep(Duration::from_millis(50)).await;
                }
            }
        }
    });

    tokio::signal::ctrl_c().await?;
    Ok(())
}
