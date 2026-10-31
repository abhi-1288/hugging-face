# serve-local.ps1 - starts a localhost OpenAI-compatible model server for agents.
#
# Usage:
#   .\serve-local.ps1 hf           -> transformers serve (models\huggingface auto-served), port 8000
#   .\serve-local.ps1 hf <name>    -> preloaded model (e.g. hf qwen3-4b)
#   .\serve-local.ps1 llama        -> llama.cpp GGUF server, first GGUF found, port 8080
#   .\serve-local.ps1 llama <name> -> specific model (e.g. llama liquidai/lfm3-vl-2b-gguf)
#   .\serve-local.ps1 ollama       -> ollama serve (checks it is installed), port 11434
param(
    [Parameter(Position = 0)][ValidateSet("hf", "llama", "ollama")][string]$Engine = "hf",
    [Parameter(Position = 1)][string]$Model = "",
    [int]$Port = 0,
    [switch]$Cpu            # llama.cpp only: no GPU offload (for laptops)
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $root "setup.ps1")   # env vars + venv

# resolve a model arg ("qwen3-4b", "Qwen/Qwen3-4B", "liquidai/lfm3-vl-2b-gguf")
# to models\huggingface\<org>\<model>\, or "" if none given
function Resolve-HfModel([string]$arg) {
    $mroot = Join-Path $root "models\huggingface"
    if (-not $arg) { return $null }
    if (Test-Path $arg) { return $arg }
    $l = $arg.ToLower() -replace '\\', '/'
    $parts = $l.Split('/')
    if ($parts.Count -ge 2) {
        $p = Join-Path $mroot "$($parts[-2])\$($parts[-1])"
        if (Test-Path $p) { return $p }
    }
    $hit = Get-ChildItem $mroot -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory } |
           Where-Object { $_.Name -eq $parts[-1] -and $_.Parent.Parent.FullName -eq $mroot } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    Write-Host "Model '$arg' not found under $mroot. Download first:" -ForegroundColor Red
    Write-Host "  .\download-model.ps1 $arg" -ForegroundColor Yellow
    exit 1
}

switch ($Engine) {
    "hf" {
        # transformers serve needs a model (id or local path) — auto-pick the
        # first TRANSFORMERS model on this drive when none was named.
        # GGUF-only folders are skipped: raw GGUFs are served by llama/Ollama.
        $pre = Resolve-HfModel $Model
        if (-not $pre) {
            $isTransformersModel = { param($d)
                (Test-Path (Join-Path $d "config.json")) -and (Get-ChildItem $d -Filter "*.safetensors" -ErrorAction SilentlyContinue) }
            $first = Get-ChildItem (Join-Path $root "models\huggingface") -Directory |
                     ForEach-Object { Get-ChildItem $_.FullName -Directory } |
                     Where-Object { & $isTransformersModel $_.FullName } | Select-Object -First 1
            if (-not $first) {
                $hasGguf = Get-ChildItem (Join-Path $root "models\huggingface") -Recurse -Filter *.gguf | Select-Object -First 1
                if ($hasGguf) {
                    Write-Host "Only GGUF models found - serve them with:" -ForegroundColor Yellow
                    Write-Host "  .\serve-local.ps1 llama      (or .\run-model.ps1)" -ForegroundColor Green
                } else {
                    Write-Host "No models in models\huggingface. Download one:  .\download-model.ps1 Qwen/Qwen3-4B" -ForegroundColor Red
                }
                exit 1
            }
            $pre = $first.FullName
        }
        elseif (-not (Test-Path (Join-Path $pre "config.json")) -and (Get-ChildItem $pre -Filter *.gguf)) {
            Write-Host "'$pre' is a raw GGUF folder - transformers cannot serve it. Use:" -ForegroundColor Yellow
            Write-Host "  .\serve-local.ps1 llama $Model" -ForegroundColor Green
            exit 1
        }
        $args_ = @("serve", $pre)
        if ($Port -ne 0) { $args_ += @("--port", $Port) } else { $Port = 8000 }
        Write-Host "Starting HF server on http://localhost:$Port/v1 (model: $pre) (Ctrl+C to stop)" -ForegroundColor Green
        & (Join-Path $root ".venv\Scripts\transformers.exe") @args_
    }
    "llama" {
        $dir = Resolve-HfModel $Model
        if (-not $dir) {
            # pick the first gguf under models\huggingface
            $dir = (Get-ChildItem (Join-Path $root "models\huggingface") -Recurse -Filter *.gguf | Select-Object -First 1).Directory.FullName
        }
        $gguf = Get-ChildItem $dir -Filter *.gguf | Select-Object -First 1
        if (-not $gguf) { Write-Host "No .gguf in $dir. GGUFs can't be run by llama.cpp; use hf engine." -ForegroundColor Red; exit 1 }
        $server = Get-ChildItem (Join-Path $root "tools") -Recurse -Filter "llama-server.exe" | Select-Object -First 1
        if (-not $server) { Write-Host "llama-server.exe not found (tools\ still downloading?)." -ForegroundColor Red; exit 1 }
        if ($Port -eq 0) { $Port = 8080 }
        $ngl = if ($Cpu) { 0 } else { 99 }
        Write-Host "Serving $gguf.Name on http://localhost:$Port/v1  (Ctrl+C to stop)" -ForegroundColor Green
        & $server.FullName -m $gguf.FullName -ngl $ngl -c 4096 --port $Port --host 127.0.0.1
    }
    "ollama" {
        $exe = Get-Command "ollama.exe" -ErrorAction SilentlyContinue
        if (-not $exe) {
            Write-Host "Ollama is NOT installed on this PC." -ForegroundColor Red
            Write-Host "Install it once from https://ollama.com/download/windows" -ForegroundColor Yellow
            Write-Host "Its models will still live on THIS drive (OLLAMA_MODELS is set to models\ollama)." -ForegroundColor Yellow
            exit 1
        }
        if ($Port -eq 0) { $Port = 11434 }
        $env:OLLAMA_HOST = "127.0.0.1:$Port"
        Write-Host "Starting Ollama on http://localhost:$Port  (OpenAI path: /v1, Ctrl+C to stop)" -ForegroundColor Green
        & $exe.Source serve
    }
}
