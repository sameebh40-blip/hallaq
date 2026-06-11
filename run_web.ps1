$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) {
  $invPath = $MyInvocation.MyCommand.Path
  if (-not [string]::IsNullOrWhiteSpace($invPath)) {
    $root = Split-Path -Parent $invPath
  } else {
    $root = (Get-Location).Path
  }
}
if ([string]::IsNullOrWhiteSpace($root)) { throw "Could not determine project root. Run: cd C:\Users\k\Desktop\hallaq ; .\run_web.ps1" }
Push-Location $root

$envFile = Join-Path $root ".env.local"
$envMap = @{}
if (Test-Path $envFile) {
  foreach ($line in (Get-Content $envFile)) {
    $t = ($line -replace '^[\s`"]+|[\s`"]+$', '')
    if ([string]::IsNullOrWhiteSpace($t)) { continue }
    if ($t.StartsWith("#")) { continue }
    $idx = $t.IndexOf("=")
    if ($idx -lt 1) { continue }
    $k = $t.Substring(0, $idx).Trim()
    $v = $t.Substring($idx + 1)
    $v = ($v -replace '^[\s`"]+|[\s`"]+$', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($k)) { $envMap[$k] = $v }
  }
}

$supabaseUrl = $env:SUPABASE_URL
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
  if ($envMap.ContainsKey("SUPABASE_URL")) {
    $supabaseUrl = $envMap["SUPABASE_URL"]
  }
}
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
  if ($envMap.ContainsKey("NEXT_PUBLIC_SUPABASE_URL")) {
    $supabaseUrl = $envMap["NEXT_PUBLIC_SUPABASE_URL"]
  }
}
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
  $supabaseUrl = Read-Host "Enter SUPABASE_URL"
}

$supabaseUrl = $supabaseUrl.Replace('`', '').Replace('"', '').Trim()
if ([string]::IsNullOrWhiteSpace($supabaseUrl)) { throw "SUPABASE_URL is empty" }

if (-not ($supabaseUrl -match '^https?://')) {
  $supabaseUrl = "https://$supabaseUrl"
}

if ($supabaseUrl -notmatch 'supabase\.co') {
  throw "SUPABASE_URL must be your Supabase project URL like https://xxxx.supabase.co (do not paste localhost or the anon key)."
}

$supabaseUrl = ($supabaseUrl -replace '^(https?://[^/]+).*$','$1')

$anonKey = $env:SUPABASE_ANON_KEY
if ([string]::IsNullOrWhiteSpace($anonKey)) {
  if ($envMap.ContainsKey("SUPABASE_ANON_KEY")) {
    $anonKey = $envMap["SUPABASE_ANON_KEY"]
  }
}
if ([string]::IsNullOrWhiteSpace($anonKey)) {
  if ($envMap.ContainsKey("NEXT_PUBLIC_SUPABASE_ANON_KEY")) {
    $anonKey = $envMap["NEXT_PUBLIC_SUPABASE_ANON_KEY"]
  }
}
if ([string]::IsNullOrWhiteSpace($anonKey)) {
  $anonKeySecure = Read-Host "Enter SUPABASE_ANON_KEY" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($anonKeySecure)
  $anonKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$anonKey = $anonKey.Replace('`', '').Replace('"', '').Trim()
if ([string]::IsNullOrWhiteSpace($anonKey)) { throw "SUPABASE_ANON_KEY is empty" }

$parts = $anonKey.Split('.')
if ($parts.Length -ne 3) { throw "SUPABASE_ANON_KEY must be a JWT (three parts separated by dots)." }
if ($anonKey.Length -lt 100) { throw "SUPABASE_ANON_KEY looks too short. Paste the full anon (public) key." }

Write-Host ("SUPABASE_URL=" + $supabaseUrl)
Write-Host ("SUPABASE_ANON_KEY length=" + $anonKey.Length)

$supabaseDebug = $env:SUPABASE_DEBUG
if ([string]::IsNullOrWhiteSpace($supabaseDebug)) {
  if ($envMap.ContainsKey("SUPABASE_DEBUG")) {
    $supabaseDebug = $envMap["SUPABASE_DEBUG"]
  } elseif ($envMap.ContainsKey("NEXT_PUBLIC_SUPABASE_DEBUG")) {
    $supabaseDebug = $envMap["NEXT_PUBLIC_SUPABASE_DEBUG"]
  } else {
    $supabaseDebug = "false"
  }
}
$supabaseDebug = $supabaseDebug.Replace('`', '').Replace('"', '').Trim()

$port = 0
for ($i = 0; $i -lt 200; $i++) {
  $candidate = Get-Random -Minimum 52000 -Maximum 59999
  try {
    $inUse = Get-NetTCPConnection -LocalPort $candidate -ErrorAction SilentlyContinue
    if ($null -eq $inUse) { $port = $candidate; break }
  } catch {
    $port = $candidate
    break
  }
}
if ($port -eq 0) { $port = 51943 }

$device = $env:WEB_DEVICE
if ([string]::IsNullOrWhiteSpace($device)) { $device = "web-server" }

$mode = $env:WEB_MODE
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = "release" }
$mode = $mode.Replace('`', '').Replace('"', '').Trim().ToLowerInvariant()
if (@("debug","profile","release") -notcontains $mode) { $mode = "release" }
$modeFlag = @()
if ($mode -ne "debug") { $modeFlag = @("--$mode") }

$renderer = $env:WEB_RENDERER
if ([string]::IsNullOrWhiteSpace($renderer)) {
  if ($mode -eq "debug") { $renderer = "html" } else { $renderer = "canvaskit" }
}
$renderer = $renderer.Replace('`', '').Replace('"', '').Trim().ToLowerInvariant()
if (@("auto","html","canvaskit") -notcontains $renderer) { $renderer = "canvaskit" }
$rendererFlag = @()
$rendererDefineFlag = @()
if ($renderer -eq "canvaskit") { $rendererDefineFlag = @("--dart-define=FLUTTER_WEB_USE_SKIA=true") }
elseif ($renderer -eq "html") { $rendererDefineFlag = @("--dart-define=FLUTTER_WEB_USE_SKIA=false") }

if ($renderer -ne "auto") {
  $help = ""
  try {
    $help = (flutter run -h 2>&1 | Out-String)
  } catch {}
  if ($help -match "--web-renderer") {
    $rendererFlag = @("--web-renderer", $renderer)
  } else {
    Write-Host "Note: your Flutter SDK doesn't support --web-renderer; falling back to FLUTTER_WEB_USE_SKIA dart-define."
  }
}

function Open-Url([string] $url) {
  $browser = $env:WEB_BROWSER
  $b = ""
  if (-not [string]::IsNullOrWhiteSpace($browser)) {
    $b = $browser.Replace('`', '').Replace('"', '').Trim().ToLowerInvariant()
  }

  $preferChrome = [string]::IsNullOrWhiteSpace($b) -or $b -eq "chrome"

  $candidates = @(
    (Get-Command "chrome" -ErrorAction SilentlyContinue).Source,
    (Get-Command "chrome.exe" -ErrorAction SilentlyContinue).Source,
    (Join-Path ${env:ProgramFiles} "Google\Chrome\Application\chrome.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
    (Join-Path ${env:LocalAppData} "Google\Chrome\Application\chrome.exe")
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

  if (-not $preferChrome) {
    Start-Process $url | Out-Null
    return
  }

  $incognito = $env:WEB_INCOGNITO
  if ([string]::IsNullOrWhiteSpace($incognito)) { $incognito = "" } else { $incognito = $incognito.Replace('`', '').Replace('"', '').Trim() }

  $appMode = $env:WEB_APP
  if ([string]::IsNullOrWhiteSpace($appMode)) { $appMode = "" } else { $appMode = $appMode.Replace('`', '').Replace('"', '').Trim().ToLowerInvariant() }

  $args = @("--new-window")
  if ($incognito -eq "1" -or $incognito.ToLowerInvariant() -eq "true") {
    $args += "--incognito"
  }

  if ($appMode -eq "1" -or $appMode -eq "true") {
    $args += "--app=$url"
    $args += "--window-size=430,900"
  } else {
    $args += $url
  }

  foreach ($p in $candidates) {
    if (Test-Path $p) {
      Start-Process -FilePath $p -ArgumentList $args | Out-Null
      return
    }
  }

  Start-Process $url | Out-Null
}

if ($device -eq "web-server") {
  $cb = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $url = "http://localhost:$port/?cb=$cb"
  Write-Host ("Open: " + $url)
  Open-Url $url
  flutter run -d web-server --web-hostname localhost --web-port $port @modeFlag @rendererFlag @rendererDefineFlag `
    "--dart-define=SUPABASE_URL=$supabaseUrl" `
    "--dart-define=SUPABASE_ANON_KEY=$anonKey" `
    "--dart-define=SUPABASE_DEBUG=$supabaseDebug"
} else {
  flutter run -d $device --web-hostname localhost --web-port $port @modeFlag @rendererFlag @rendererDefineFlag `
    "--dart-define=SUPABASE_URL=$supabaseUrl" `
    "--dart-define=SUPABASE_ANON_KEY=$anonKey" `
    "--dart-define=SUPABASE_DEBUG=$supabaseDebug"
}

Pop-Location
