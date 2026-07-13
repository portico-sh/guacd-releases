# guacd Windows service installer (via WinSW).
#
# Run in an ELEVATED PowerShell (Administrator). Provide the enrollment code via
# an environment variable (so it works through `irm | iex`):
#
#   $env:GUACD_ENROLL_CODE = '<ENROLLMENT_CODE>'
#   irm https://raw.githubusercontent.com/portico-sh/guacd-releases/main/install-service.ps1 | iex
#
# Optional: $env:GUACD_SERVER, $env:GUACD_VERSION.
#
# Installs guacd.exe to %ProgramFiles%\guacd, enrolls it into %ProgramData%\guacd,
# and registers a Windows service (runs on boot, restarts on failure) using the
# WinSW wrapper — guacd.exe is a console app, so a wrapper provides the SCM
# integration and log files. Manage it in services.msc or with `sc`.
$ErrorActionPreference = 'Stop'

$Repo = 'portico-sh/guacd-releases'
$Base = "https://raw.githubusercontent.com/$Repo/main"
$InstallDir = Join-Path $env:ProgramFiles 'guacd'
$BinPath = Join-Path $InstallDir 'guacd.exe'
$WrapperExe = Join-Path $InstallDir 'guacd-service.exe'
$WrapperXml = Join-Path $InstallDir 'guacd-service.xml'
$ConfigDir = Join-Path $env:ProgramData 'guacd'
# Pinned WinSW v2 (requires .NET Framework 4.6.1+, present on Win10/Server 2016+).
$WinSwUrl = 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe'

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# --- Preconditions -----------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
      [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin) { throw 'Run this in an elevated PowerShell (Administrator).' }

$code = $env:GUACD_ENROLL_CODE
if (-not $code) {
    throw 'Set $env:GUACD_ENROLL_CODE to your enrollment code (Portico UI: Daemons -> Generate code) before running.'
}
$server = $env:GUACD_SERVER

New-Item -ItemType Directory -Force -Path $InstallDir, $ConfigDir | Out-Null

# --- 1. Install guacd.exe to Program Files (reuses install.ps1) --------------
Info "Installing guacd to $InstallDir..."
$env:GUACD_BIN_DIR = $InstallDir
Invoke-Expression (Invoke-RestMethod "$Base/install.ps1") | Out-Null

# --- 2. Download the WinSW service wrapper -----------------------------------
Info 'Downloading service wrapper (WinSW)...'
Invoke-WebRequest -Uri $WinSwUrl -OutFile $WrapperExe -UseBasicParsing

# --- 3. Enroll into the shared config dir ------------------------------------
Info 'Enrolling daemon...'
$enrollArgs = @('enroll', $code, '--config-dir', $ConfigDir)
if ($server) { $enrollArgs += @('--server', $server) }
& $BinPath @enrollArgs
if ($LASTEXITCODE -ne 0) { throw 'Enrollment failed (code invalid or expired? generate a fresh one).' }

# --- 4. Write the WinSW config (must share the wrapper's base name) -----------
$runArgs = "run --config-dir `"$ConfigDir`""
if ($server) { $runArgs += " --server `"$server`"" }
$xml = @"
<service>
  <id>guacd</id>
  <name>guacd (Portico daemon)</name>
  <description>Portico protocol-runner daemon.</description>
  <executable>$BinPath</executable>
  <arguments>$runArgs</arguments>
  <workingdirectory>$InstallDir</workingdirectory>
  <onfailure action="restart" delay="5 sec" />
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>5</keepFiles>
  </log>
</service>
"@
Set-Content -Path $WrapperXml -Value $xml -Encoding UTF8

# --- 5. Install + start the service ------------------------------------------
Info 'Installing and starting the service...'
& $WrapperExe install
& $WrapperExe start

Info 'Done. guacd runs as a Windows service (see services.msc).'
Write-Host "  Logs:   $InstallDir\guacd-service.out.log" -ForegroundColor Gray
Write-Host "  Manage: sc stop guacd | sc start guacd  (or services.msc)" -ForegroundColor Gray
