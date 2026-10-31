# install-torch.ps1 - installs PyTorch into THIS folder's venv (never global C: Python).
#
# Usage:
#   .\install-torch.ps1 cpu        # small ~250 MB build, works on every machine
#   .\install-torch.ps1 gpu        # CUDA 12.x build, ~2.5-3 GB, needs NVIDIA
#   .\install-torch.ps1 check      # show which build is currently installed
param(
    [Parameter(Position = 0)][ValidateSet("cpu", "gpu", "cuda", "check")][string]$Build = "check"
)
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$pypip = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $pypip)) {
    Write-Host ".venv missing - create it first:  python -m venv $root\.venv" -ForegroundColor Red
    exit 1
}

# force caches to this drive even outside an activated venv
$env:PIP_CACHE_DIR = Join-Path $root "temp\pip"
$env:TMP  = Join-Path $root "temp"
$env:TEMP = Join-Path $root "temp"

# sanity: confirm we are using the venv, NOT C:\Python314
$pipTarget = & $pypip -c "import sys; print(sys.prefix)"
Write-Host "Installing into: $pipTarget" -ForegroundColor Cyan
if ($pipTarget -notlike "*$root*") { Write-Host "Refusing: not the local venv." -ForegroundColor Red; exit 1 }

function Show-Torch {
    & $pypip -c "import torch; print('torch', torch.__version__, '| cuda available:', torch.cuda.is_available())"
}

if ($Build -eq "check") { Show-Torch; exit 0 }

# remove any previous build (CPU and CUDA builds cannot coexist)
& $pypip -m pip uninstall torch -y *> $null

if ($Build -eq "cpu") {
    & $pypip -m pip install torch --index-url https://download.pytorch.org/whl/cpu
} else {
    & $pypip -m pip install torch --index-url https://download.pytorch.org/whl/cu128
}
if ($LASTEXITCODE -ne 0) { Write-Host "Install failed." -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Installed:" -ForegroundColor Green
Show-Torch