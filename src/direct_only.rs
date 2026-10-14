use hbb_common::config;

pub(crate) fn configure() {
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    for (key, value) in [
        ("direct-server", "Y"),
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
