# PowerShell script to build the TBScreen Linux desktop application via Docker
param(
    [string]$Platform = "linux/arm64",
    [switch]$RebuildImage = $false
)

$ErrorActionPreference = "Stop"

$ArchTag = if ($Platform -like "*arm64*") { "arm64" } else { "x64" }

Write-Host "=== TBScreen Linux Desktop Docker Build ($Platform) ===" -ForegroundColor Cyan

# 1. Check Docker daemon availability
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& docker info > $null 2>&1
$dockerExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP

if ($dockerExit -ne 0) {
    Write-Host "`n[ERROR] Docker daemon is not running." -ForegroundColor Red
    Write-Host "Please start Docker Desktop on your machine and ensure the whale icon is running in the taskbar." -ForegroundColor Yellow
    Write-Host "Once Docker Desktop is active, run this script again:`n  .\docker\build_linux.ps1`n" -ForegroundColor Yellow
    exit 1
}

$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$DockerDir = Join-Path $ProjectRoot "docker\linux-build"
$ImageName = "tbscreen-linux-builder:$ArchTag"

# 2. Build or verify Docker image
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"

$imageExists = docker images -q $ImageName
if (-not $imageExists -or $RebuildImage) {
    Write-Host "`nBuilding builder Docker image ($ImageName) for $Platform..." -ForegroundColor Green
    & docker buildx build --platform $Platform -t $ImageName -f (Join-Path $DockerDir "Dockerfile") $DockerDir --load
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker builder image."
        exit $LASTEXITCODE
    }
} else {
    Write-Host "Reusing existing builder image ($ImageName). Pass -RebuildImage to force rebuild." -ForegroundColor DarkGray
}

# 3. Run build container
Write-Host "`nStarting build inside Linux ($Platform) container..." -ForegroundColor Green
& docker run --rm --platform $Platform -v "${ProjectRoot}:/workspace" $ImageName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Linux build inside container failed."
    exit $LASTEXITCODE
}
$ErrorActionPreference = $prevEAP

# 4. Verification
$BundlePath = Join-Path $ProjectRoot "build\linux\$ArchTag\release\bundle\tbscreen"
$TarPath = Join-Path $ProjectRoot "build\linux\tbscreen-linux-$ArchTag.tar.gz"

if (Test-Path $TarPath) {
    $tarItem = Get-Item $TarPath
    Write-Host "`n[SUCCESS] Linux Desktop ($Platform) application built successfully!" -ForegroundColor Green
    Write-Host "Executable Bundle: $BundlePath" -ForegroundColor White
    Write-Host "Release Tarball:   $TarPath ($([math]::Round($tarItem.Length / 1MB, 2)) MB)" -ForegroundColor White
} else {
    Write-Host "`n[WARNING] Build finished but tarball was not found at $TarPath" -ForegroundColor Yellow
}

