[CmdletBinding()]
param(
  [string]$DeviceId,
  [switch]$Clean,
  [switch]$NoPubGet,
  [switch]$Release,
  [switch]$VerboseFlutter,
  [switch]$ForcePubCache,
  [int]$MinProjectFreeGB = 8,
  [string]$CacheRoot,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }

function Add-ToPath([string]$PathToAdd) {
  if ([string]::IsNullOrWhiteSpace($PathToAdd)) { return }
  if (-not (Test-Path $PathToAdd)) { return }
  $resolved = (Resolve-Path $PathToAdd).Path
  $existing = @(
    $env:Path -split ';' |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object {
        try { (Resolve-Path $_ -ErrorAction Stop).Path } catch { $_ }
      }
  )
  if ($existing -notcontains $resolved) { $env:Path = "$resolved;$env:Path" }
}

if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:HALLAQ_CACHE_ROOT)) {
    $CacheRoot = $env:HALLAQ_CACHE_ROOT
  } elseif (Test-Path "G:\") {
    $CacheRoot = "G:\hallaq_cache"
  } else {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "hallaq_cache"
  }
}

$env:HALLAQ_CACHE_ROOT = $CacheRoot

$tempRoot = Join-Path $CacheRoot "temp"
$gradleHome = Join-Path $CacheRoot "gradle_home"
$pubCache = Join-Path $CacheRoot "pub_cache"
$dartToolTarget = Join-Path $CacheRoot "dart_tool"

$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$env:GRADLE_USER_HOME = $gradleHome

$projectDrive = Split-Path -Qualifier (Resolve-Path (Get-Location)).Path
$cacheDrive = Split-Path -Qualifier (Resolve-Path $CacheRoot).Path
$useCustomPubCache = $ForcePubCache -or ($projectDrive -eq $cacheDrive)

foreach ($d in @($projectDrive, $cacheDrive) | Select-Object -Unique) {
  $dName = $d.TrimEnd('\').TrimEnd(':')
  $dInfo = Get-PSDrive -Name $dName -ErrorAction SilentlyContinue
  if ($null -ne $dInfo) {
    $freeGB = [math]::Floor(($dInfo.Free / 1GB))
    if ($freeGB -lt $MinProjectFreeGB) {
      throw "Low disk space on drive $d ($freeGB GB free). Free space or move the repo/build folder (recommended), then re-run."
    }
  }
}

if ($useCustomPubCache) {
  $env:PUB_CACHE = $pubCache
} else {
  Remove-Item Env:PUB_CACHE -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $tempRoot, $gradleHome | Out-Null
if ($useCustomPubCache) { New-Item -ItemType Directory -Force -Path $pubCache | Out-Null }
New-Item -ItemType Directory -Force -Path $dartToolTarget | Out-Null

$dartToolLink = Join-Path $RootDir ".dart_tool"
$skipDartToolJunction = $false
if (Test-Path $dartToolLink) {
  $item = Get-Item $dartToolLink -Force
  $isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
  if (-not $isReparse) {
    try {
      Remove-Item -Recurse -Force $dartToolLink -ErrorAction Stop
    } catch {
      try {
        Stop-Process -Name dart -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Remove-Item -Recurse -Force $dartToolLink -ErrorAction Stop
      } catch {
        Write-Host ("[run_android] WARN: could not remove .dart_tool (locked). Using existing .dart_tool for this run.")
        $skipDartToolJunction = $true
      }
    }
  }
}
if (-not $skipDartToolJunction -and -not (Test-Path $dartToolLink)) {
  New-Item -ItemType Junction -Path $dartToolLink -Target $dartToolTarget | Out-Null
}

$buildTarget = Join-Path $CacheRoot "build"
New-Item -ItemType Directory -Force -Path $buildTarget | Out-Null
$buildLink = Join-Path $RootDir "build"
if (Test-Path $buildLink) {
  $item = Get-Item $buildLink -Force
  $isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
  if (-not $isReparse) {
    try {
      Remove-Item -Recurse -Force $buildLink -ErrorAction Stop
    } catch {
      Write-Host ("[run_android] WARN: could not remove build (locked). Using existing build for this run.")
    }
  }
}
if (-not (Test-Path $buildLink)) {
  New-Item -ItemType Junction -Path $buildLink -Target $buildTarget | Out-Null
}

$wrapperProps = Join-Path $RootDir "android\gradle\wrapper\gradle-wrapper.properties"
if (Test-Path $wrapperProps) {
  $distLine = (Get-Content $wrapperProps -ErrorAction SilentlyContinue | Where-Object { $_ -match '^distributionUrl=' } | Select-Object -First 1)
  if ($distLine -match 'gradle-(\d+\.\d+(?:\.\d+)?)-') {
    $gradleVersion = $Matches[1]
    New-Item -ItemType Directory -Force -Path (Join-Path $gradleHome ("daemon\" + $gradleVersion)) | Out-Null
  } else {
    New-Item -ItemType Directory -Force -Path (Join-Path $gradleHome "daemon") | Out-Null
  }
} else {
  New-Item -ItemType Directory -Force -Path (Join-Path $gradleHome "daemon") | Out-Null
}

if ([string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
  $sdkCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
    (Join-Path $env:USERPROFILE ".android\sdk"),
    "C:\Android\Sdk"
  )
  $env:ANDROID_SDK_ROOT = ($sdkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
}
if ([string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT) -or -not (Test-Path $env:ANDROID_SDK_ROOT)) {
  throw "ANDROID_SDK_ROOT not found. Set ANDROID_SDK_ROOT (or install Android SDK)."
}
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT

if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
  $javaCandidates = @(
    "C:\Program Files\Android\Android Studio\jbr",
    "C:\Program Files\Android\Android Studio\jbr\Contents\Home"
  )
  $env:JAVA_HOME = ($javaCandidates | Where-Object { Test-Path (Join-Path $_ "bin\java.exe") } | Select-Object -First 1)
}
if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME) -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
  Add-ToPath (Join-Path $env:JAVA_HOME "bin")
}

$sdkPlatformTools = Join-Path $env:ANDROID_SDK_ROOT "platform-tools"
$sdkCmdlineTools = Join-Path $env:ANDROID_SDK_ROOT "cmdline-tools\latest\bin"
Add-ToPath $sdkPlatformTools
Add-ToPath $sdkCmdlineTools

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutterCmd) { throw "flutter not found in PATH. Install Flutter and ensure flutter is available in this terminal." }
Write-Host ("[run_android] flutter=" + $flutterCmd.Source)

$adb = Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($null -eq $adbCmd) { throw "adb not found. Install Android platform-tools (or fix ANDROID_SDK_ROOT)." }
  $adb = $adbCmd.Source
}

function Invoke-NativeCapture([string]$ExePath, [string[]]$CommandArgs) {
  $previousPreference = $ErrorActionPreference
  $script:ErrorActionPreference = "Continue"
  try {
    return @(& $ExePath @CommandArgs 2>&1)
  } finally {
    $script:ErrorActionPreference = $previousPreference
  }
}

function Ensure-AdbServer([string]$AdbPath) {
  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    $out = Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("start-server")
    $devicesOut = Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("devices")
    $joined = (($out + $devicesOut) -join "`n")
    if ($joined -notmatch "cannot connect to daemon|failed to start daemon|failed to check server version|could not read ok from ADB Server") {
      return
    }

    try { & $AdbPath kill-server | Out-Null } catch {}
    Start-Sleep -Seconds 1
  }
  throw "ADB server cannot be started. Replug USB, close tools using port 5037, then run: adb kill-server; adb start-server; adb devices"
}

function Get-DeviceState([string]$AdbPath, [string]$TargetDeviceId) {
  $lines = Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("devices")
  foreach ($line in $lines) {
    $text = ([string]$line).Trim()
    if ($text -match ("^" + [regex]::Escape($TargetDeviceId) + "\s+(\S+)$")) {
      return $Matches[1]
    }
  }
  return ""
}

function Get-DevicesSnapshot([string]$AdbPath) {
  $lines = Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("devices")
  $clean = @(
    $lines |
      ForEach-Object { ([string]$_).TrimEnd() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )
  return ($clean -join "; ")
}

function Ensure-DeviceOnline([string]$AdbPath, [string]$TargetDeviceId) {
  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    $state = Get-DeviceState $AdbPath $TargetDeviceId
    if ($state -eq "device") { return }

    if ($state -eq "offline") {
      Write-Host ("[run_android] WARN: device is offline, attempting adb reconnect (" + ($attempt + 1) + "/3)")
      try { Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("reconnect", "offline") | Out-Null } catch {}
      Start-Sleep -Seconds 2
    }

    try { Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("-s", $TargetDeviceId, "wait-for-device") | Out-Null } catch {}
    Start-Sleep -Seconds 1
    $state = Get-DeviceState $AdbPath $TargetDeviceId
    if ($state -eq "device") { return }

    try { Invoke-NativeCapture -ExePath $AdbPath -CommandArgs @("kill-server") | Out-Null } catch {}
    Start-Sleep -Seconds 1
    Ensure-AdbServer $AdbPath
    Start-Sleep -Seconds 1
  }

  $finalState = Get-DeviceState $AdbPath $TargetDeviceId
  if ([string]::IsNullOrWhiteSpace($finalState)) { $finalState = "not detected" }
  $snapshot = Get-DevicesSnapshot $AdbPath
  if ([string]::IsNullOrWhiteSpace($snapshot)) { $snapshot = "(no output)" }
  throw "Android device '$TargetDeviceId' is '$finalState'. adb devices: $snapshot. Replug USB, unlock the phone, accept the RSA prompt if shown, then re-run."
}

Ensure-AdbServer $adb

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  $deviceList = @(
    (Invoke-NativeCapture -ExePath $adb -CommandArgs @("devices")) |
      Select-String "`tdevice$" |
      ForEach-Object { ($_ -split "\s+")[0] }
  )

  if ($deviceList.Count -eq 0) { throw "No authorized Android device detected. Check USB debugging + authorization, then re-run." }

  if ($deviceList.Count -eq 1) {
    $DeviceId = $deviceList[0]
  } else {
    for ($i = 0; $i -lt $deviceList.Count; $i++) { Write-Host ("[{0}] {1}" -f $i, $deviceList[$i]) }
    $picked = Read-Host "Select device index"
    if ($picked -notmatch '^\d+$') { throw "Invalid device index." }
    $idx = [int]$picked
    if ($idx -lt 0 -or $idx -ge $deviceList.Count) { throw "Invalid device index." }
    $DeviceId = $deviceList[$idx]
  }
}

Ensure-DeviceOnline $adb $DeviceId

if ($Clean) {
  $gradlewBat = Join-Path $RootDir "android\gradlew.bat"
  if (Test-Path $gradlewBat) {
    try { & $gradlewBat --stop | Out-Null } catch {}
  }
  try { Stop-Process -Name dart -Force -ErrorAction SilentlyContinue } catch {}
  try { Stop-Process -Name java -Force -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Milliseconds 500
  if (Test-Path $buildTarget) {
    try {
      Get-ChildItem -Force $buildTarget -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop
    } catch {
      Write-Host "[run_android] WARN: could not fully clear build cache target before flutter clean."
    }
  }
  flutter clean
}

if (-not $NoPubGet) {
  flutter pub get
}

function Read-EnvFile([string]$Path) {
  $map = @{}
  if (-not (Test-Path $Path)) { return $map }
  foreach ($line in (Get-Content $Path -ErrorAction SilentlyContinue)) {
    $t = ([string]$line).Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { continue }
    if ($t.StartsWith("#")) { continue }
    $idx = $t.IndexOf("=")
    if ($idx -lt 1) { continue }
    $k = $t.Substring(0, $idx).Trim()
    $v = $t.Substring($idx + 1).Trim()
    if ($v.Length -ge 2) {
      if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        $v = $v.Substring(1, $v.Length - 2)
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($k)) { $map[$k] = $v }
  }
  return $map
}

$envMapLocal = Read-EnvFile (Join-Path $RootDir ".env.local")
$envMapExample = Read-EnvFile (Join-Path $RootDir ".env.example")

function Is-PlaceholderConfigValue([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
  $trimmed = $Value.Trim()
  return $trimmed -match 'YOUR_PROJECT\.supabase\.co|YOUR_ANON_KEY|YOUR_SERVICE_ROLE_KEY|YOUR_PROJECT_URL'
}

function Resolve-EnvValueAny([string[]]$Keys) {
  foreach ($k in $Keys) {
    $v = Resolve-EnvValue $k
    if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
  }
  return $null
}

function Resolve-EnvValue([string]$Key) {
  $fromProcess = [Environment]::GetEnvironmentVariable($Key, "Process")
  if (-not [string]::IsNullOrWhiteSpace($fromProcess) -and -not (Is-PlaceholderConfigValue $fromProcess)) { return $fromProcess }
  $fromUser = [Environment]::GetEnvironmentVariable($Key, "User")
  if (-not [string]::IsNullOrWhiteSpace($fromUser) -and -not (Is-PlaceholderConfigValue $fromUser)) { return $fromUser }
  $fromMachine = [Environment]::GetEnvironmentVariable($Key, "Machine")
  if (-not [string]::IsNullOrWhiteSpace($fromMachine) -and -not (Is-PlaceholderConfigValue $fromMachine)) { return $fromMachine }
  if ($envMapLocal.ContainsKey($Key) -and -not (Is-PlaceholderConfigValue $envMapLocal[$Key])) { return $envMapLocal[$Key] }
  if ($envMapExample.ContainsKey($Key) -and -not (Is-PlaceholderConfigValue $envMapExample[$Key])) { return $envMapExample[$Key] }
  return $null
}

$supabaseUrl = Resolve-EnvValueAny @("SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_URL")
$supabaseAnonKey = Resolve-EnvValueAny @("SUPABASE_ANON_KEY", "NEXT_PUBLIC_SUPABASE_ANON_KEY")
if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw "Supabase not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env.local (or .env.example, or environment variables), then re-run."
}

$appId = "com.example.hallaq"
$appGradle = Join-Path $RootDir "android\\app\\build.gradle.kts"
if (Test-Path $appGradle) {
  $line = (Get-Content $appGradle -ErrorAction SilentlyContinue | Where-Object { $_ -match 'applicationId\\s*=\\s*\"([^\"]+)\"' } | Select-Object -First 1)
  if ($line -match 'applicationId\\s*=\\s*\"([^\"]+)\"') {
    $appId = $Matches[1]
  }
}

$supabaseDebug = Resolve-EnvValueAny @("SUPABASE_DEBUG", "NEXT_PUBLIC_SUPABASE_DEBUG")
if ([string]::IsNullOrWhiteSpace($supabaseDebug)) { $supabaseDebug = "false" }
$adminPanelUrl = Resolve-EnvValueAny @("ADMIN_PANEL_URL", "NEXT_PUBLIC_ADMIN_PANEL_URL")
if ([string]::IsNullOrWhiteSpace($adminPanelUrl)) { $adminPanelUrl = "https://admin.hallaq.com" }

function Sanitize-Value([string]$v) {
  if ($null -eq $v) { return $null }
  $out = $v.Trim()
  $out = $out.Replace('`', '').Replace('"', '')
  $out = $out.Trim()
  if ($out.Length -ge 2) {
    $first = $out.Substring(0, 1)
    $last = $out.Substring($out.Length - 1, 1)
    if (($first -eq "'" -and $last -eq "'") -or ($first -eq '`' -and $last -eq '`') -or ($first -eq '"' -and $last -eq '"')) {
      $out = $out.Substring(1, $out.Length - 2).Trim()
    }
  }
  return $out
}

function Sanitize-Url([string]$v) {
  $out = Sanitize-Value $v
  if ([string]::IsNullOrWhiteSpace($out)) { return $out }
  if ($out -match '(https?://[^\s`"]+)') {
    $out = $Matches[1]
  }
  $out = $out -replace '^[`"\s]+', ''
  $out = $out -replace '[`"\s]+$', ''
  return $out.Trim()
}

function Sanitize-Token([string]$v) {
  $out = Sanitize-Value $v
  if ([string]::IsNullOrWhiteSpace($out)) { return $out }
  $out = $out -replace '\s+', ''
  if ($out -match '(eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+)') {
    $out = $Matches[1]
  }
  return $out
}

$supabaseUrl = Sanitize-Url $supabaseUrl
$supabaseAnonKey = Sanitize-Token $supabaseAnonKey
$supabaseDebug = (Sanitize-Value $supabaseDebug)
$adminPanelUrl = Sanitize-Url $adminPanelUrl

Write-Host ("[run_android] device=" + $DeviceId)
Write-Host ("[run_android] appId=" + $appId)
Write-Host ("[run_android] SUPABASE_URL=" + $supabaseUrl)
Write-Host ("[run_android] SUPABASE_ANON_KEY.length=" + $supabaseAnonKey.Length)

$uninstallOut = @()
try { & $adb shell am force-stop $appId 2>&1 | Out-Null } catch {}
try { $uninstallOut = & $adb uninstall $appId 2>&1 } catch { $uninstallOut = @($_.Exception.Message) }
if ($uninstallOut -and ($uninstallOut -join "`n") -match 'DELETE_FAILED') {
  Write-Host ("[run_android] WARN: adb uninstall failed: " + (($uninstallOut -join ' ') -replace '\s+', ' '))
}

$flutterExe = (Get-Command flutter -ErrorAction Stop).Source

$flutterCmdArgs = @("build", "apk")
if ($Release) { $flutterCmdArgs += "--release" } else { $flutterCmdArgs += "--debug" }
if ($VerboseFlutter) { $flutterCmdArgs = @("-v") + $flutterCmdArgs }
$flutterCmdArgs += ("--dart-define=SUPABASE_URL=" + $supabaseUrl)
$flutterCmdArgs += ("--dart-define=SUPABASE_ANON_KEY=" + $supabaseAnonKey)
$flutterCmdArgs += ("--dart-define=SUPABASE_DEBUG=" + $supabaseDebug)
$flutterCmdArgs += ("--dart-define=ADMIN_PANEL_URL=" + $adminPanelUrl)
if ($FlutterArgs -and $FlutterArgs.Count -gt 0) { $flutterCmdArgs += $FlutterArgs }

Write-Host ("[run_android] flutter " + ($flutterCmdArgs -join " "))
& $flutterExe @flutterCmdArgs
if ($LASTEXITCODE -ne 0) {
  throw "flutter build failed with exit code $LASTEXITCODE"
}

$apk = if ($Release) {
  Join-Path $RootDir "build\app\outputs\flutter-apk\app-release.apk"
} else {
  Join-Path $RootDir "build\app\outputs\flutter-apk\app-debug.apk"
}
if (-not (Test-Path $apk)) {
  throw "APK not found at $apk"
}

Write-Host ("[run_android] adb install -r " + $apk)
& $adb -s $DeviceId install -r $apk
if ($LASTEXITCODE -ne 0) {
  throw "adb install failed with exit code $LASTEXITCODE"
}

try { & $adb -s $DeviceId logcat -c | Out-Null } catch {}

Write-Host ("[run_android] launching " + $appId)
$startOut = @()
try {
  $startOut = & $adb -s $DeviceId shell am start -W -n ($appId + "/.MainActivity") 2>&1
} catch {
  $startOut = @($_.Exception.Message)
}
if ($startOut) {
  Write-Host "[run_android] am start output:"
  ($startOut -join "`n") | Write-Host
}

try {
  Start-Sleep -Seconds 15

  $logPath = Join-Path $RootDir "build\android_last_logcat.txt"
  & $adb -s $DeviceId logcat -b all -d -t 2000 | Out-File -FilePath $logPath -Encoding utf8
  Write-Host ("[run_android] saved logcat(all): " + $logPath)

  $crashPath = Join-Path $RootDir "build\android_last_crash.txt"
  & $adb -s $DeviceId logcat -b crash -d -t 400 | Out-File -FilePath $crashPath -Encoding utf8
  Write-Host ("[run_android] saved logcat(crash): " + $crashPath)

  $fatalPath = Join-Path $RootDir "build\android_last_fatal.txt"
  (Get-Content $logPath -ErrorAction SilentlyContinue | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime|Process: com\.example\.hallaq|com\.example\.hallaq" -CaseSensitive:$false) |
    ForEach-Object { $_.Line } |
    Out-File -FilePath $fatalPath -Encoding utf8
  Write-Host ("[run_android] saved logcat(fatal-filter): " + $fatalPath)
} catch {
  Write-Host ("[run_android] WARN: could not save logcat: " + $_.Exception.Message)
}
