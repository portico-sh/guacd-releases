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
guacd enroll <ENROLLMENT_CODE>     # redeem the code, saves credentials
guacd run                          # start the daemon
```

By default `guacd` talks to the hosted service (`https://app.portico.sh`). For a
self-hosted deployment, pass `--server https://your-host` or set the
`GUACD_SERVER` environment variable.

Credentials are stored under `~/.config/guacd` (Linux/macOS) or the equivalent
per-user config directory on Windows.
