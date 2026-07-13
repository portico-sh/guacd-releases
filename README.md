# guacd releases

Prebuilt binaries and cross-platform installers for **guacd**, the Portico
protocol-runner daemon. It dials out to Portico over WebRTC — no inbound ports
on your host, no firewall changes.

> This repository contains **binaries and install scripts only** — no source code.

## Install

### Linux / macOS

```sh
curl -fsSL https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install.sh | sh
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install.ps1 | iex
```

The installer downloads the latest release, installs the `guacd` binary to a
directory on your `PATH`, and prints next steps.

**Overrides** (both installers): set `GUACD_VERSION` to pin a tag (e.g.
`v0.3.2`) and `GUACD_BIN_DIR` to choose the install location.

### Manual download

Grab an archive from the [Releases](https://github.com/portico-sh/guacd-releases/releases)
page and extract the `guacd` binary:

| Platform        | Asset                                   |
| --------------- | --------------------------------------- |
| Linux x86_64    | `guacd-<version>-linux-x86_64.tar.gz`   |
| Windows x86_64  | `guacd-<version>-windows-x86_64.zip`    |

## Usage

Generate a single-use enrollment code in the Portico UI (**Daemons** → Generate
code), then on the host:

```sh
guacd run --enroll-code <ENROLLMENT_CODE>   # redeem the code and start the daemon
```

The daemon self-enrolls on first run and caches credentials, so every later
start is just `guacd run`.

By default `guacd` talks to the hosted service (`https://app.portico.sh`). For a
self-hosted deployment, pass `--server https://your-host` or set the
`GUACD_SERVER` environment variable.

Credentials are stored under `~/.config/guacd` (Linux/macOS) or the equivalent
per-user config directory on Windows.

## Run as a service (recommended for hosts)

`guacd run` is a foreground process. To run it in the background, on boot, with
automatic restart, install it as a service. These install the binary
system-wide, create a system config dir, enroll the daemon, and register the
service — one command, run as admin/root.

**Linux (systemd):**

```sh
curl -fsSL https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install-service.sh \
  | sudo sh -s -- --enroll-code <ENROLLMENT_CODE>
```
Runs as a dedicated `guacd` user; config in `/var/lib/guacd`; logs via
`journalctl -u guacd`. Manage with `systemctl {status,stop,start,restart} guacd`.

**Windows (elevated PowerShell):**

```powershell
$env:GUACD_ENROLL_CODE = '<ENROLLMENT_CODE>'
irm https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install-service.ps1 | iex
```
Config in `%ProgramData%\guacd`; the service is wrapped with
[WinSW](https://github.com/winsw/winsw) (guacd is a console app). Manage in
`services.msc` or with `sc {stop,start} guacd`; logs in
`%ProgramFiles%\guacd\guacd-service.out.log`.

Both accept `--server <url>` / `$env:GUACD_SERVER` for self-hosted control
planes and `--webrtc-port <port>` / `$env:GUACD_WEBRTC_PORT` to change the
webrtc-direct UDP port (default 4001). macOS (launchd) is planned.
