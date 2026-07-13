#!/bin/sh
# guacd systemd service installer (Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install-service.sh \
#     | sudo sh -s -- --enroll-code <ENROLLMENT_CODE> [--server URL] [--listen MULTIADDR]
#
# Installs the guacd binary to /usr/local/bin, creates a dedicated unprivileged
# `guacd` user, enrolls the daemon into a system config dir, and installs +
# starts a systemd service that runs it on boot and restarts it on failure.
# Logs go to journald: `journalctl -u guacd`.
#
# Env alternatives to the flags: GUACD_ENROLL_CODE, GUACD_SERVER,
# GUACD_LISTEN_ADDRS, GUACD_VERSION.
set -eu

REPO="portico-sh/guacd-releases"
BASE="https://raw.githubusercontent.com/${REPO}/main"
BIN_DIR="/usr/local/bin"
BIN="${BIN_DIR}/guacd"
CONFIG_DIR="/var/lib/guacd"
SVC_USER="guacd"
UNIT="/etc/systemd/system/guacd.service"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
err() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- Args --------------------------------------------------------------------
CODE="${GUACD_ENROLL_CODE:-}"
SERVER="${GUACD_SERVER:-}"
LISTEN="${GUACD_LISTEN_ADDRS:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --enroll-code) CODE="${2:-}"; shift 2 ;;
    --enroll-code=*) CODE="${1#*=}"; shift ;;
    --server) SERVER="${2:-}"; shift 2 ;;
    --server=*) SERVER="${1#*=}"; shift ;;
    --listen) LISTEN="${2:-}"; shift 2 ;;
    --listen=*) LISTEN="${1#*=}"; shift ;;
    -h | --help)
      printf 'usage: install-service.sh --enroll-code <CODE> [--server URL] [--listen MULTIADDR]\n'
      exit 0
      ;;
    *) err "unknown argument: $1" ;;
  esac
done

# --- Preconditions -----------------------------------------------------------
[ "$(id -u)" = "0" ] || err "must run as root (use sudo)"
command -v systemctl >/dev/null 2>&1 || err "systemd (systemctl) is required"
[ -n "$CODE" ] ||
  err "an enrollment code is required (--enroll-code <CODE>, or GUACD_ENROLL_CODE). Generate one in the Portico UI: Daemons -> Generate code."

# --- 1. Install the binary system-wide (reuses install.sh) -------------------
info "Installing guacd to ${BIN_DIR}..."
GUACD_BIN_DIR="$BIN_DIR" GUACD_VERSION="${GUACD_VERSION:-}" \
  sh -c "$(curl -fsSL "${BASE}/install.sh")" >/dev/null ||
  err "binary install failed"

# --- 2. Dedicated system user ------------------------------------------------
if ! id "$SVC_USER" >/dev/null 2>&1; then
  info "Creating system user '${SVC_USER}'..."
  useradd --system --home-dir "$CONFIG_DIR" --shell /usr/sbin/nologin "$SVC_USER" ||
    err "failed to create user '${SVC_USER}'"
fi

# --- 3. Config dir owned by the service user ---------------------------------
mkdir -p "$CONFIG_DIR"
chown "$SVC_USER:$SVC_USER" "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# --- 4. Enroll (writes credentials + identity into CONFIG_DIR as the user) ---
info "Enrolling daemon..."
su -s /bin/sh "$SVC_USER" -c \
  "'$BIN' enroll '$CODE' --config-dir '$CONFIG_DIR' ${SERVER:+--server '$SERVER'}" ||
  err "enrollment failed (code invalid or expired? generate a fresh one)"

# --- 5. Write the unit -------------------------------------------------------
info "Writing ${UNIT}..."
{
  printf '%s\n' \
    '[Unit]' \
    'Description=guacd - Portico protocol-runner daemon' \
    'After=network-online.target' \
    'Wants=network-online.target' \
    '' \
    '[Service]' \
    'Type=simple' \
    "User=${SVC_USER}" \
    "Group=${SVC_USER}" \
    "Environment=GUACD_CONFIG_DIR=${CONFIG_DIR}"
  [ -n "$SERVER" ] && printf 'Environment=GUACD_SERVER=%s\n' "$SERVER"
  [ -n "$LISTEN" ] && printf 'Environment=GUACD_LISTEN_ADDRS=%s\n' "$LISTEN"
  printf '%s\n' \
    "ExecStart=${BIN} run" \
    'Restart=on-failure' \
    'RestartSec=5' \
    'NoNewPrivileges=true' \
    'ProtectSystem=strict' \
    'ProtectHome=true' \
    'PrivateTmp=true' \
    "ReadWritePaths=${CONFIG_DIR}" \
    '' \
    '[Install]' \
    'WantedBy=multi-user.target'
} >"$UNIT"

# --- 6. Enable + start -------------------------------------------------------
info "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable --now guacd

info "Done. guacd is running as a systemd service."
printf '\n  systemctl status guacd\n  journalctl -u guacd -f\n\n'
