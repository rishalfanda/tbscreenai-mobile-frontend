param(
    [string]$ApiBaseUrl = 'http://10.0.2.2:8000/api/v1',
    [string]$Device = 'emulator-5554',
    [string]$Flutter = 'C:\Users\devel\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    & $Flutter --no-version-check run --flavor staging -d $Device `
        --dart-define=APP_ENV=staging --dart-define=USE_HTTP=true `
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
