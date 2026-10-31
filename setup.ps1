# setup.ps1 - activates the Python environment and points all caches to this drive.
# Run with:  . .\setup.ps1      (note the leading dot + space = "dot-source" activate)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Session-only temp override (safe: does not touch Windows globally)
$env:TMP  = Join-Path $root "temp"
$env:TEMP = Join-Path $root "temp"

# THESE are ALSO set permanently via setx (see GUIDE.md). Setting again here
# makes them correct even if the drive letter changes on another machine.
$env:HF_HOME       = Join-Path $root "models\huggingface"
$env:HF_HUB_CACHE  = Join-Path $root "models\huggingface\hub"
$env:HF_XET_CACHE  = Join-Path $root "models\huggingface\xet"
$env:PIP_CACHE_DIR = Join-Path $root "temp\pip"
$env:UV_CACHE_DIR  = Join-Path $root "temp\uv"
$env:OLLAMA_MODELS = Join-Path $root "models\ollama"

$venvActivate = Join-Path $root ".venv\Scripts\Activate.ps1"
if (-not (Test-Path $venvActivate)) {
    Write-Host "INFO: .venv not found. Create it with:" -ForegroundColor Yellow
    Write-Host "    python -m venv $root\.venv"
    Write-Host "    (then: pip install torch --index-url https://download.pytorch.org/whl/cpu"
    Write-Host "           pip install transformers accelerate diffusers huggingface_hub safetensors sentencepiece)"
    Write-Host ""
} else {
    & $venvActivate
}

# Keep the folder view clean: infra folders (hidden) still work normally.
foreach ($f in @(".venv", "temp", "tools")) {
    $p = Join-Path $root $f
    if (Test-Path $p) { attrib +H $p *> $null }
}

if ($venvActivate -and (Test-Path $venvActivate)) {
    Write-Host ">>> Environment ready (venv active). Usage tips:" -ForegroundColor Green
    Write-Host "    Download model : .\download-model.ps1 Qwen/Qwen3-4B"
    Write-Host "    Run a model    : .\run-model.ps1        (browser-free: pick engine, pick model, run)"
    Write-Host "    List models    : Get-ChildItem models\huggingface -Directory | Get-ChildItem -Directory"
    Write-Host "    (internal folders like .venv/caches/temp/tools are hidden - they still work)"
    Write-Host ""
}
