param(
  [string]$Flavor = "demo",
  [string]$AppEnv = "demo",
  [string]$ApiBaseUrl = "https://3rgcn2lx-8000.asse.devtunnels.ms/v1",
  [string]$ImageTag = "tbscreen-builder"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$MountedRoot = $ProjectRoot -replace '\\', '/'

$DistDir = Join-Path $ProjectRoot "dist"
if (-not (Test-Path $DistDir)) {
  New-Item -ItemType Directory -Path $DistDir | Out-Null
}

Write-Host "Building TBScreen for Linux ARM64 (Raspberry Pi 5)..." -ForegroundColor Cyan
Write-Host "  Flavor:       $Flavor"
Write-Host "  APP_ENV:      $AppEnv"
Write-Host "  API_BASE_URL: $ApiBaseUrl"

docker run --rm --platform linux/arm64 `
  -e FLAVOR="$Flavor" `
  -e APP_ENV="$AppEnv" `
  -e API_BASE_URL="$ApiBaseUrl" `
  -v "${MountedRoot}:/src:ro" `
  -v "${MountedRoot}/dist:/out" `
  -v tbscreen-pub-cache:/root/.pub-cache `
  $ImageTag bash -c "
    set -e
    rsync -a --delete --exclude build --exclude .dart_tool /src/ /work/
    cd /work
    flutter pub get
    flutter build linux --release \
      --flavor \`$FLAVOR \
      --dart-define=APP_ENV=\`$APP_ENV \
      --dart-define=API_BASE_URL=\`$API_BASE_URL
    
    BUNDLE_SRC=\"build/linux/arm64/\`$FLAVOR/release/bundle\"
    if [ ! -d \"\`$BUNDLE_SRC\" ]; then
      BUNDLE_SRC=\"build/linux/arm64/release/bundle\"
    fi

    rm -rf /out/bundle
    cp -r \"\`$BUNDLE_SRC\" /out/bundle

    # Ensure all ONNX Runtime shared libraries and symlinks are in /out/bundle/lib
    find build/linux/arm64 -path "*/flutter_onnxruntime/onnxruntime/*/lib/libonnxruntime.so*" -exec cp -d {} /out/bundle/lib/ \; 2>/dev/null || true
    if [ -f /out/bundle/lib/libonnxruntime.so ] && [ ! -e /out/bundle/lib/libonnxruntime.so.1 ]; then
      ln -sf libonnxruntime.so /out/bundle/lib/libonnxruntime.so.1
    fi
  "

Write-Host "Build complete! Output bundle located at: $DistDir\bundle" -ForegroundColor Green
