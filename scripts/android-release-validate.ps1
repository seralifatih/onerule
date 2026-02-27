param(
    [string]$PackageName = "com.fidevelopment.onerule",
    [string]$DeviceId = "",
    [switch]$NoBuild,
    [switch]$NoInstall,
    [switch]$NoUninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-AdbArgs {
    param([string[]]$CommandArgs)
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        return $CommandArgs
    }
    return @("-s", $DeviceId) + $CommandArgs
}

function Invoke-Adb {
    param([string[]]$CommandArgs)
    & adb @(Get-AdbArgs -CommandArgs $CommandArgs)
}

function Ensure-Tool {
    param([string]$ToolName)
    if (-not (Get-Command $ToolName -ErrorAction SilentlyContinue)) {
        throw "Required tool not found on PATH: $ToolName"
    }
}

function Ensure-Device {
    Write-Step "Checking ADB devices"
    $devices = @((& adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match "\S" })
    if ($devices.Count -eq 0) {
        throw "No ADB device detected. Connect phone and enable USB debugging."
    }

    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $selected = $devices | Where-Object { $_ -match "^$([regex]::Escape($DeviceId))\s+device$" }
        if (-not $selected) {
            throw "Device '$DeviceId' is not connected as 'device'."
        }
    }

    $devices | ForEach-Object { Write-Host $_ }
}

function Ensure-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Expected file not found: $Path"
    }
}

Ensure-Tool -ToolName "flutter"
Ensure-Tool -ToolName "adb"
Ensure-Device

Write-Step "Flutter version"
flutter --version

if (-not $NoBuild) {
    Write-Step "flutter clean"
    flutter clean

    Write-Step "flutter pub get"
    flutter pub get

    Write-Step "flutter build apk --release"
    flutter build apk --release
}

$apkPath = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk\app-release.apk"
$apkPath = [System.IO.Path]::GetFullPath($apkPath)
Ensure-File -Path $apkPath

if (-not $NoInstall) {
    if (-not $NoUninstall) {
        Write-Step "adb uninstall $PackageName (non-fatal if absent)"
        try {
            Invoke-Adb -CommandArgs @("uninstall", $PackageName) | Out-Host
        } catch {
            Write-Host "Uninstall failed or package not present. Continuing." -ForegroundColor Yellow
        }
    }

    Write-Step "adb install -r app-release.apk"
    Invoke-Adb -CommandArgs @("install", "-r", $apkPath) | Out-Host
}

Write-Step "Launch app and capture crash buffer"
Invoke-Adb -CommandArgs @("logcat", "-c") | Out-Null
Invoke-Adb -CommandArgs @("shell", "monkey", "-p", $PackageName, "-c", "android.intent.category.LAUNCHER", "1") | Out-Host
Start-Sleep -Seconds 5
$crashLog = Invoke-Adb -CommandArgs @("logcat", "-b", "crash", "-d") 2>&1

$fatal = $crashLog | Select-String -Pattern "Wrong full snapshot version|dart_vm_initializer|Fatal signal|FATAL" -SimpleMatch:$false
if ($fatal) {
    Write-Host ""
    Write-Host "Crash indicators detected in crash buffer:" -ForegroundColor Red
    $fatal | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
    throw "Release validation failed due to crash indicators."
}

Write-Step "Verify process is alive"
$appPid = (Invoke-Adb -CommandArgs @("shell", "pidof", $PackageName) 2>$null) -join ""
if ([string]::IsNullOrWhiteSpace($appPid)) {
    throw "App process not running after launch. Validate manually on device."
}

Write-Host ""
Write-Host "Release validation passed. PID: $appPid" -ForegroundColor Green
Write-Host "APK: $apkPath" -ForegroundColor Green
