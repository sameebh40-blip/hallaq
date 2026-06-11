$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) {
  $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Push-Location $root

$renderer = $env:WEB_RENDERER
if ([string]::IsNullOrWhiteSpace($renderer)) { $renderer = "canvaskit" }
$renderer = $renderer.Replace('`', '').Replace('"', '').Trim()

$rendererFlag = @()
try {
  $help = (flutter build web -h 2>&1 | Out-String)
  if ($help -match '--web-renderer') {
    $rendererFlag = @("--web-renderer", $renderer)
  }
} catch {
  $rendererFlag = @()
}

flutter build web --release @rendererFlag

Pop-Location

