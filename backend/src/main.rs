#![windows_subsystem = "windows"]

use std::sync::{Arc, Mutex};

use anyhow::Result;
use remote_trackpad_backend::{network, ui};

fn main() -> Result<()> {
    let config = Arc::new(Mutex::new(ui::ServerConfig::default()));
    let local_ip = ui::get_local_ip();

    let (shutdown_tx, shutdown_rx) = tokio::sync::watch::channel(false);

    let network_config = Arc::clone(&config);
    let network_thread = std::thread::spawn(move || {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(network::run_server(network_config, shutdown_rx))
    });

    let ui_result = ui::run_ui(config, local_ip);
    let _ = shutdown_tx.send(true);
    network_thread
        .join()
        .map_err(|_| anyhow::anyhow!("backend thread panicked"))??;
    ui_result?;
    Ok(())
}
