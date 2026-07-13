# guacd installer for Windows (PowerShell).
#
#   irm https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install.ps1 | iex
#
# Downloads the latest prebuilt guacd.exe from portico-sh/guacd-releases,
# installs it to %LOCALAPPDATA%\Programs\guacd, and adds that dir to the user
# PATH.
#
# Environment overrides:
#   $env:GUACD_VERSION   Install a specific tag (e.g. v0.3.2) instead of latest.
#   $env:GUACD_BIN_DIR   Install location (default: %LOCALAPPDATA%\Programs\guacd).

$ErrorActionPreference = 'Stop'

$Repo = 'portico-sh/guacd-releases'
$BinName = 'guacd.exe'

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- Detect platform ---------------------------------------------------------
# Check the OS architecture, NOT the PowerShell process arch: a 32-bit
# PowerShell on 64-bit Windows reports x86 via $env:PROCESSOR_ARCHITECTURE
# (WOW64), which would wrongly reject a supported machine. x86_64 binaries also
# run on ARM64 Windows via built-in emulation.
if (-not [Environment]::Is64BitOperatingSystem) {
    throw "Unsupported architecture: 32-bit Windows (only x86_64/AMD64 is published today)"
}
$platform = 'windows-x86_64'

# --- Resolve version ---------------------------------------------------------
if ($env:GUACD_VERSION) {
    $version = $env:GUACD_VERSION
} else {
    Info 'Resolving latest release...'
    $latest = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $version = $latest.tag_name
    if (-not $version) { throw 'Could not determine latest version (set $env:GUACD_VERSION to pin one)' }
}

$asset = "guacd-$version-$platform.zip"
$url = "https://github.com/$Repo/releases/download/$version/$asset"

# --- Pick install dir --------------------------------------------------------
if ($env:GUACD_BIN_DIR) {
    $binDir = $env:GUACD_BIN_DIR
} else {
    $binDir = Join-Path $env:LOCALAPPDATA 'Programs\guacd'
}
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# --- Download + extract ------------------------------------------------------
$tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP ("guacd-" + [guid]::NewGuid()))
try {
    Info "Downloading $asset ($version)..."
    $zip = Join-Path $tmp $asset
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Info 'Extracting...'
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    $src = Join-Path $tmp "guacd-$version-$platform\$BinName"
    if (-not (Test-Path $src)) { throw "Binary not found in archive: $src" }

    Copy-Item $src (Join-Path $binDir $BinName) -Force
    Info "Installed $BinName to $binDir\$BinName"
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# --- Add to user PATH --------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
    Info "Added $binDir to your user PATH (restart your terminal to pick it up)."
}

Write-Host @"

Next steps:

  guacd run --enroll-code <ENROLLMENT_CODE>   # redeem a code (from the Portico UI) and start the daemon

The daemon self-enrolls on first run and caches credentials, so every later
start is just `guacd run`.

By default guacd talks to the hosted service (https://app.portico.sh).
For a self-hosted server, pass --server https://your-host or set GUACD_SERVER.
"@
