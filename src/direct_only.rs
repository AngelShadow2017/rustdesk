use hbb_common::config;
use std::sync::atomic::{AtomicU8, Ordering};

static LISTENER_STATE: AtomicU8 = AtomicU8::new(0);

pub(crate) fn set_listener_state(state: u8) {
    LISTENER_STATE.store(state, Ordering::Relaxed);
}

pub(crate) fn status() -> String {
    let addresses: Vec<_> = default_net::get_interfaces()
        .into_iter()
        .flat_map(|interface| {
            let name = interface.friendly_name.unwrap_or(interface.name);
            let tailscale = name.to_lowercase().contains("tailscale");
            let physical = matches!(
                interface.if_type,
                default_net::interface::InterfaceType::Ethernet
                    | default_net::interface::InterfaceType::Wireless80211
            ) && !name.to_lowercase().starts_with("vethernet");
            interface.ipv4.into_iter().filter_map(move |ip| {
                if tailscale || (physical && ip.addr.is_private()) {
                    Some(serde_json::json!({
                        "name": if tailscale { "Tailscale" } else { "局域网" },
                        "interface": name,
                        "address": format!("{}:21118", ip.addr),
                    }))
                } else {
                    None
                }
            })
        })
        .collect();
    serde_json::json!({
        "listener": LISTENER_STATE.load(Ordering::Relaxed),
        "password_set": config::Config::has_permanent_password(),
        "sessions": crate::Connection::direct_only_session_count(),
        "addresses": addresses,
    })
    .to_string()
}

#[no_mangle]
pub extern "C" fn rustdesk_direct_only_enabled() -> bool {
    true
}

#[no_mangle]
pub extern "C" fn rustdesk_direct_only_session_count() -> usize {
    crate::Connection::direct_only_session_count()
}

#[no_mangle]
pub extern "C" fn rustdesk_direct_only_prepare_quit() {
    crate::server::input_service::fix_key_down_timeout_at_exit();
    for child in crate::server::CHILD_PROCESS.lock().unwrap().iter_mut() {
        if let Err(err) = child.kill() {
            hbb_common::log::warn!("Failed to stop direct-only child process: {err}");
        }
    }
}

pub(crate) fn configure() {
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    for (key, value) in [
        ("direct-server", "Y"),
        ("stop-service", ""),
        ("direct-access-port", "21118"),
        ("whitelist", ","),
        ("verification-method", "use-permanent-password"),
        ("approve-mode", "password"),
        ("enable-keyboard", "Y"),
        ("enable-clipboard", "Y"),
        ("enable-file-transfer", "N"),
        ("enable-tunnel", "N"),
        ("enable-terminal", "N"),
        ("enable-camera", "N"),
        ("enable-remote-printer", "N"),
        ("enable-remote-restart", "N"),
        ("enable-record-session", "N"),
        ("enable-privacy-mode", "N"),
        ("allow-remote-config-modification", "N"),
        ("allow-auto-update", "N"),
        ("enable-lan-discovery", "N"),
        ("allow-websocket", "N"),
    ] {
        settings.insert(key.to_owned(), value.to_owned());
    }
    drop(settings);
    let mut local = config::OVERWRITE_LOCAL_SETTINGS.write().unwrap();
    for key in [
        "enable-check-update",
        "enable-file-copy-paste",
        "enable-webrtc",
        "enable-udp-punch",
        "enable-ipv6-punch",
        "allow-sync-clipboard-between-sessions",
        "pre-elevate-service",
    ] {
        local.insert(key.to_owned(), "N".to_owned());
    }
    drop(local);
    let mut builtin = config::BUILTIN_SETTINGS.write().unwrap();
    for (key, value) in [
        ("direct-only", "Y"),
        ("register-device", "N"),
        ("one-way-file-transfer", "Y"),
        ("allow-remote-cm-modification", "N"),
        ("allow-logon-screen-password", "N"),
        ("allow-deep-link-password", "N"),
        ("allow-deep-link-server-settings", "N"),
        ("hide-elevate-button-in-accept-window", "Y"),
    ] {
        builtin.insert(key.to_owned(), value.to_owned());
    }
}
