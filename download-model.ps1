# download-model.ps1 - downloads a HuggingFace model into ONE flat, self-contained
# folder using the structure:
#
#     Qwen/Qwen3-4B            -> models\huggingface\qwen\qwen3-4b\
#     openai/whisper-large-v3  -> models\huggingface\openai\whisper-large-v3\
#
# ollama models go to models\ollama\ automatically (OLLAMA_MODELS) when you use:
#     ollama run hf.co/<org>/<name>:<quant>
#
# Usage:
#   .\download-model.ps1 Qwen/Qwen3-4B
#   .\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF "*Q4_K_M*"
#   .\download-model.ps1 mistralai/Mistral-7B-Instruct-v0.3 -Force
#
# All files are REAL files (no symlinks) - folder is copyable by USB to other machines.
param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [string[]]$Include = @(),
    [string[]]$Exclude = @(),
    [string]$Name = "",          # override the folder name of the model
    [switch]$Force               # skip size checks / confirmations
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# force correct caches inside this drive, even in a fresh terminal
$env:HF_HOME       = Join-Path $root "models\huggingface"
$env:HF_HUB_CACHE  = Join-Path $root "models\huggingface\hub"
$env:HF_XET_CACHE  = Join-Path $root "models\huggingface\xet"
$env:PIP_CACHE_DIR = Join-Path $root "temp\pip"

# pick the hf CLI
$hf = Join-Path $root ".venv\Scripts\hf.exe"
if (-not (Test-Path $hf)) { $hf = "hf" }

# ---- resolve destination: models\huggingface\<org>\<model>
$parts = ($Repo -replace '\\', '/').Split('/')
if ($parts.Count -lt 2) { throw "Repo must look like 'org/name' (e.g. Qwen/Qwen3-4B)" }
$orgD    = ($parts[$parts.Count - 2] -replace '[\s\.]+', '-').ToLower()
$modelD  = if ($Name) { $Name } else { ($parts[$parts.Count - 1] -replace '[\s\.]+', '-').ToLower() }
$dest    = Join-Path $root "models\huggingface\$orgD\$modelD"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# ---- auto-sense: paste any repo ID and it just works ----
# GGUF repos default to the first sensible quant (Q4_K_M preferred) + mmproj for
# vision models, instead of downloading every quant.
if ($Include.Count -eq 0) {
    $repoName = $parts[$parts.Count - 1].ToLower()
    if ($repoName -match 'gguf' -or $parts[$parts.Count - 1] -match '(?i)gguf') {
        $picked = & (Join-Path $root ".venv\Scripts\python.exe") (Join-Path $root "scripts\pick-gguf.py") $Repo
        if ($LASTEXITCODE -eq 0 -and $picked) {
            $Include = @($picked.Split('|'))
            Write-Host ("Auto-sensed GGUF files: {0}" -f ($Include -join ", ")) -ForegroundColor Yellow
            Write-Host "  (override with: .\download-model.ps1 $Repo -Include '*Q8_0*')" -ForegroundColor DarkGray
        }
    }
}

# ---- size guard (broken-in examples like 1T models will refuse) ----
if (-not $Force) {
    $size = & (Join-Path $root ".venv\Scripts\python.exe") -c "from huggingface_hub import HfApi; import sys; api=HfApi(); i=api.model_info(sys.argv[1], files_metadata=True); p=sys.argv[2]; print(sum(f.size or 0 for f in i.siblings if (not p or any(__import__('fnmatch').fnmatch(f.rfilename, pat) for pat in p.split('|')))))" $Repo ($Include -join "|")
    if ($LASTEXITCODE -eq 0 -and $size -match "^\d+$") {
        $sizeGB = [math]::Round($size / 1GB, 1)
        $free = (Get-PSDrive $root.Substring(0,1)).Free
        $freeGB = [math]::Round($free / 1GB, 1)
        Write-Host ("Size: {0} GB   Free here: {1} GB" -f $sizeGB, $freeGB) -ForegroundColor Cyan
        if ($size -gt $free * 0.9) {
            Write-Host "DOES NOT FIT on this drive. Aborting (use -Force to override)." -ForegroundColor Red
            exit 1
        }
        if ($sizeGB -gt 10) {
            $a = Read-Host "Large model ($sizeGB GB of $freeGB GB free). Continue? [y/N]"
            if ($a -notmatch "^[Yy]") { Write-Host "Cancelled."; exit 0 }
        }
    }
}

Write-Host "Repo  : $Repo"  -ForegroundColor Cyan
Write-Host "Folder: $dest"  -ForegroundColor Cyan

$argList = @("download", $Repo, "--local-dir", $dest)
if ($Include.Count -gt 0) { foreach ($p in $Include) { $argList += @("--include", $p) } }
if ($Exclude.Count -gt 0) { foreach ($p in $Exclude) { $argList += @("--exclude", $p) } }

& $hf @argList
if ($LASTEXITCODE -ne 0) { Write-Host "Download failed. Check: https://huggingface.co/$Repo" -ForegroundColor Red; exit 1 }

# hide the internal HF metadata folder inside the model folder (still functional)
Get-ChildItem $dest -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like ".cache*" } |
    ForEach-Object { $_.Attributes = $_.Attributes -bor [IO.FileAttributes]::Hidden }

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Get-ChildItem $dest -Force -File | ForEach-Object { "  {0,10:N1} MB  {1}" -f ($_.Length / 1MB), $_.Name }
