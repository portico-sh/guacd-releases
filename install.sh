#!/bin/sh
# guacd installer for Linux and macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install.sh | sh
#
# Downloads the latest prebuilt guacd binary from the portico-sh/guacd-releases
# GitHub releases, verifies the platform, and installs it to a bin dir on PATH.
#
# Environment overrides:
#   GUACD_VERSION   Install a specific tag (e.g. v0.3.2) instead of latest.
#   GUACD_BIN_DIR   Install location (default: ~/.local/bin, or /usr/local/bin
#                   when writable / running as root).
set -eu

REPO="portico-sh/guacd-releases"
BIN_NAME="guacd"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
err() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- Detect platform ---------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)  os_tag="linux" ;;
  Darwin) err "macOS builds are not published yet. Build from source, or watch $REPO for macOS assets." ;;
  *)      err "unsupported OS: $os (only Linux is published today)" ;;
esac

case "$arch" in
  x86_64 | amd64) arch_tag="x86_64" ;;
  *) err "unsupported architecture: $arch (only x86_64 is published today)" ;;
esac

platform="${os_tag}-${arch_tag}"

# --- Resolve version ---------------------------------------------------------
if [ "${GUACD_VERSION:-}" != "" ]; then
  version="$GUACD_VERSION"
else
  info "Resolving latest release..."
  version="$(
    curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
      | grep '"tag_name"' | head -n1 | cut -d'"' -f4
  )"
  [ -n "$version" ] || err "could not determine latest version (set GUACD_VERSION to pin one)"
fi

asset="${BIN_NAME}-${version}-${platform}.tar.gz"
url="https://github.com/${REPO}/releases/download/${version}/${asset}"

# --- Pick install dir --------------------------------------------------------
if [ "${GUACD_BIN_DIR:-}" != "" ]; then
  bin_dir="$GUACD_BIN_DIR"
elif [ "$(id -u)" = "0" ] || [ -w /usr/local/bin ]; then
  bin_dir="/usr/local/bin"
else
  bin_dir="${HOME}/.local/bin"
fi
mkdir -p "$bin_dir"

# --- Download + extract ------------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

info "Downloading ${asset} (${version})..."
curl -fsSL "$url" -o "${tmp}/${asset}" \
  || err "download failed: $url"

info "Extracting..."
tar -xzf "${tmp}/${asset}" -C "$tmp"

src="${tmp}/${BIN_NAME}-${version}-${platform}/${BIN_NAME}"
[ -f "$src" ] || err "binary not found in archive"

install -m 0755 "$src" "${bin_dir}/${BIN_NAME}"
info "Installed ${BIN_NAME} to ${bin_dir}/${BIN_NAME}"

# --- PATH hint + next steps --------------------------------------------------
case ":${PATH}:" in
  *":${bin_dir}:"*) ;;
  *) printf '\033[1;33mnote:\033[0m %s is not on your PATH. Add it:\n    export PATH="%s:$PATH"\n' "$bin_dir" "$bin_dir" ;;
esac

cat <<EOF

Next steps:

  ${BIN_NAME} enroll <ENROLLMENT_CODE>     # redeem a code from the Portico UI
  ${BIN_NAME} run                          # start the daemon

By default guacd talks to the hosted service (https://app.portico.sh).
For a self-hosted server, pass --server https://your-host or set GUACD_SERVER.
EOF
