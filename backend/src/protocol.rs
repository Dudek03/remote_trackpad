use anyhow::{anyhow, Result};

#[derive(Debug, PartialEq)]
pub enum UdpPacket {
    Move { dx: f32, dy: f32 },
    Scroll { dx: f32, dy: f32 },
}

#[derive(Debug, PartialEq, Eq)]
pub enum TcpCommand {
    LeftClick,
    RightClick,
    DoubleClick,
    AltTabStart,
    AltTabEnd,
    VolumeUp,
    VolumeDown,
}

pub fn parse_udp_payload(payload: &[u8]) -> Result<UdpPacket> {
    let payload = std::str::from_utf8(payload)?.trim();
    let mut parts = payload.split(',');
    let kind = parts.next().unwrap_or_default();

    match kind {
        "M" => Ok(UdpPacket::Move {
            dx: parse_f32(parts.next())?,
            dy: parse_f32(parts.next())?,
        }),
        "S" => Ok(UdpPacket::Scroll {
            dx: parse_f32(parts.next())?,
            dy: parse_f32(parts.next())?,
        }),
        other => Err(anyhow!("unsupported UDP packet: {other}")),
    }
}

pub fn parse_tcp_payload(payload: &[u8]) -> Result<TcpCommand> {
    let payload = std::str::from_utf8(payload)?.trim();
    match payload {
        "left_click" => Ok(TcpCommand::LeftClick),
        "right_click" => Ok(TcpCommand::RightClick),
        "double_click" => Ok(TcpCommand::DoubleClick),
        "alt_tab_start" => Ok(TcpCommand::AltTabStart),
        "alt_tab_end" => Ok(TcpCommand::AltTabEnd),
        "volume_up" => Ok(TcpCommand::VolumeUp),
        "volume_down" => Ok(TcpCommand::VolumeDown),
        other => Err(anyhow!("unsupported TCP command: {other}")),
    }
}

fn parse_f32(value: Option<&str>) -> Result<f32> {
    let value = value.ok_or_else(|| anyhow!("missing delta value"))?;
    value.trim().parse::<f32>().map_err(Into::into)
}
