# run-model.ps1 - pick provider -> pick model -> run it.
#
# Usage (interactive, just run it):
#   .\run-model.ps1
# Or skip prompts:
#   .\run-model.ps1 -Provider huggingface -Model qwen3-4b -Mode chat
#   .\run-model.ps1 -Provider huggingface -Model qwen3-4b -Mode server
#   .\run-model.ps1 -Provider ollama -Model hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M
param(
    [string]$Provider = "",
    [string]$Model = "",
    [string]$Mode = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Count-HfModels {
    @(Get-ChildItem (Join-Path $root "models\huggingface") -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem $_.FullName -Directory }).Count
}
function Get-HfModels {
    Get-ChildItem (Join-Path $root "models\huggingface") -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { $org = $_.Name; Get-ChildItem $_.FullName -Directory } |
        ForEach-Object { "$($_.Parent.Name)/$($_.Name)" }
}

# ---------- step 1: provider ----------
if (-not $Provider) {
    Write-Host ""
    Write-Host "Which provider do you want to run the model with?" -ForegroundColor Green
    $h = Count-HfModels
    $ollamaInstalled = [bool](Get-Command "ollama.exe" -ErrorAction SilentlyContinue)
    $i = 1
    if ($h -gt 0)      { Write-Host "  1) huggingface  (models\huggingface, $h model(s) on this drive)"; $i = $i + 1 }
    if ($ollamaInstalled) { Write-Host "  $i) ollama       (installed; models land in models\ollama)" } else {
        Write-Host "  $i) ollama       (NOT installed on this PC - install: https://ollama.com/download/windows)" -ForegroundColor Yellow
    }
    $pick = Read-Host "Choice [1]"
    if ($pick -eq "2" -or ($pick -eq "1" -and $h -eq 0)) { $Provider = "ollama" } else { $Provider = "huggingface" }
}

# ---------- step 2: model ----------
if (-not $Model) {
    if ($Provider -eq "huggingface") {
        $models = @(Get-HfModels)
        if ($models.Count -eq 0) {
            Write-Host "No models downloaded yet." -ForegroundColor Yellow
            $a = Read-Host "Download one now with a start repo id (blank = Qwen/Qwen3-4B)?"
            $repo = if ($a) { $a } else { "Qwen/Qwen3-4B" }
            & (Join-Path $root "download-model.ps1") $repo
            $models = @(Get-HfModels)
        }
        if ($models.Count -eq 1) {
            $Model = $models[0]
            Write-Host "Using the only model found: $Model" -ForegroundColor DarkGray
        } else {
            Write-Host ""
            Write-Host "Which model? ([id] name)" -ForegroundColor Green
            for ($j = 0; $j -lt $models.Count; $j++) { Write-Host "  [$j] $($models[$j])" }
            $sel = Read-Host "Pick [0]"
            if ($sel -eq "") { $sel = "0" }
            $Model = $models[[int]$sel]
        }
    } else {
        if (-not (Get-Command "ollama.exe" -ErrorAction SilentlyContinue)) {
            Write-Host "Ollama is not installed. Install from https://ollama.com/download/windows" -ForegroundColor Red
            Write-Host "(its models will still live on this drive - OLLAMA_MODELS is set)" -ForegroundColor Yellow
            exit 1
        }
        $installed = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] })
        if ($installed.Count -eq 0) {
            $a = Read-Host "No ollama models installed. Repo to pull (blank cancels)? e.g. hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M"
            if (-not $a) { Write-Host "Cancelled."; exit 0 }
            ollama pull $a
            $Model = $a
        } elseif ($installed.Count -eq 1) {
            $Model = $installed[0]
            Write-Host "Using: $Model" -ForegroundColor DarkGray
        } else {
            Write-Host ""
            Write-Host "Which model?" -ForegroundColor Green
            for ($j = 0; $j -lt $installed.Count; $j++) { Write-Host "  [$j] $($installed[$j])" }
            $sel = Read-Host "Pick [0]"
            if ($sel -eq "") { $sel = "0" }
            $Model = $installed[[int]$sel]
        }
    }
}

# ---------- step 3: how to run ----------
if (-not $Mode) {
    Write-Host ""
    Write-Host "How do you want to run $Model ?" -ForegroundColor Green
    Write-Host "  1) chat  - terminal chat session"
    Write-Host "  2) server - localhost OpenAI API (for agents), see AGENTS.md"
    if ($Provider -eq "huggingface") { Write-Host "             (~= transformers serve on http://localhost:8000/v1)" } else {
        Write-Host "             (~= ollama serve on http://localhost:11434)"
    }
    $m = Read-Host "Pick [1]"
    if ($m -eq "2") { $Mode = "server" } else { $Mode = "chat" }
}

# ---------- run ----------
if ($Provider -eq "huggingface") {
    if ($Mode -eq "chat") {
        & (Join-Path $root ".venv\Scripts\python.exe") (Join-Path $root "scripts\chat.py") $Model
    } else {
        & (Join-Path $root "serve-local.ps1") hf $Model
    }
} else {
    if ($Mode -eq "chat") {
        ollama run $Model
    } else {
        $env:OLLAMA_HOST = "127.0.0.1:11434"
        & "ollama.exe" serve
    }
}
