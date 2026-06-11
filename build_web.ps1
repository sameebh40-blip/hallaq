param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

$ErrorActionPreference = "Stop"

$anonKey = $SupabaseAnonKey
if ([string]::IsNullOrWhiteSpace($anonKey)) {
  $anonKeySecure = Read-Host "Enter SUPABASE_ANON_KEY (optional, leave empty for demo-only)" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($anonKeySecure)
  $anonKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$defines = @()

if (-not [string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl"
}

if (-not [string]::IsNullOrWhiteSpace($anonKey)) {
  $defines += "--dart-define=SUPABASE_ANON_KEY=$anonKey"
}

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build web --release --no-wasm-dry-run @defines
