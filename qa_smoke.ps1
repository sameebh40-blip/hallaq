$ErrorActionPreference = "Stop"

Write-Host "== Flutter analyze =="
flutter analyze

Write-Host "== Customer web lint =="
Push-Location "apps/customer"
npm run lint

Write-Host "== Customer web build =="
npm run build
Pop-Location

Write-Host "OK"

