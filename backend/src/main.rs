use std::sync::{Arc, Mutex};

use anyhow::Result;
use remote_trackpad_backend::{network, ui};

fn main() -> Result<()> {
    let config = Arc::new(Mutex::new(ui::ServerConfig::default()));
    let local_ip = ui::get_local_ip();
    println!("Remote Trackpad backend listening on {}", local_ip);

    let network_config = Arc::clone(&config);
    let network_thread = std::thread::spawn(move || {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(network::run_server(network_config))
    });

    ui::run_ui(config, local_ip)?;
    network_thread
        .join()
        .map_err(|_| anyhow::anyhow!("backend thread panicked"))??;
    Ok(())
}
