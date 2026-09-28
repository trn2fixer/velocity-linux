# Build the Velocity ISO on Windows using Docker Desktop (WSL2 backend).
# Usage: .\build.ps1            -> out\velocity-YYYY.MM.DD-x86_64.iso
#        .\build.ps1 -SkipAssets
param(
    [switch]$SkipAssets
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop is required: https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
    Write-Host "Enable the WSL2 backend during setup, then re-run .\build.ps1" -ForegroundColor Yellow
    exit 1
}

$image = "velocity-builder"
docker build -t $image . ; if ($LASTEXITCODE) { exit $LASTEXITCODE }
New-Item -ItemType Directory -Force out | Out-Null

$extra = @()
if ($SkipAssets) { $extra += "--skip-assets" }

# --privileged: mkarchiso needs loop devices and mount inside the container.
docker run --rm -it --privileged `
    -v "${PSScriptRoot}:/src" `
    -v velocity-pacman-cache:/var/cache/pacman/pkg `
    $image @extra
exit $LASTEXITCODE
