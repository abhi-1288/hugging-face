<div align="center">

# 🧠 Local HuggingFace + Ollama AI Hub

**A self-contained, portable AI stack — models, packages and caches 100% on your external drive.**

![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows11&logoColor=white)
![Python 3.14](https://img.shields.io/badge/Python-3.14-3776AB?logo=python&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-2.15-EE4C2C?logo=pytorch&logoColor=white)
![Ollama ready](https://img.shields.io/badge/Ollama-ready-F03C02?logo=ollama&logoColor=white)
![llama.cpp](https://img.shields.io/badge/llama.cpp-CUDA%2012.4-8A2BE2)

**Nothing ever installs on `C:` — drive letter agnostic, works offline, USB-copyable to your other PCs.**

[Quick start](#-quick-start) · [Structure](#-folder-structure) · [Models](#-downloading-models) · [Run](#-running-models) · [Agent servers](#-use-it-as-an-ai-provider-for-agents) · [Troubleshooting](#-troubleshooting)

</div>

---

## 📊 Architecture

```text
                         ┌──────────────────────────────────────────┐
   📡 AI agents          │            E:\abhijeet\huggingface\      │
   (OpenCode, Claude     │                                          │
   Code, any OpenAI      │   models\                                │
   client) ──────────────┼──► huggingface\ ◄─── download-model.ps1  │
   http://localhost:8000 │        qwen\qwen3-4b\        ▲           │
   :8080   :11434        │        liquidai\lfm3-...      │  copy by │
                         │      ollama\ ◄─── OLLAMA_MODELS│  USB ✉   │
                         └───┬──────────────┬───────────────────┘
                             │              │
              transformers serve      llama-server.exe (tools\)
              :8000/v1  (HF engine)   :8080/v1  (GGUF engine)
                             │              │
                       .venv\ (invisible)  ollama serve :11434/v1
                       torch + transformers
                       + diffusers + ...   (installed INTO this folder only)
```

| Engine | Model files it runs | OpenAI-compatible endpoint (localhost) |
|---|---|---|
| 🔁 **transformers / HF** | safetensors (Qwen3, Mistral, Whisper, SD…) | `http://localhost:8000/v1` |
| ⚡ **llama.cpp** | GGUF (any quant) | `http://localhost:8080/v1` |
| 🦙 **Ollama** | GGUF via `hf.co/...:Q4_K_M` | `http://localhost:11434/v1` |

---

## 📁 Folder structure

```text
E:\abhijeet\huggingface\
├── models\
│   ├── huggingface\               ← one flat folder per model, per org:
│   │   ├── qwen\qwen3-4b\             (config + tokenizer + .safetensors)
│   │   └── liquidai\lfm3-vl-2b-gguf\  (…Q4_K_M.gguf)
│   └── ollama\                    ← Ollama engine storage (OLLAMA_MODELS)
├── tools\llama.cpp-cuda\          🔒 llama.cpp portable build + CUDA runtime
├── .venv\                         🔒 Python 3.14 venv — ALL packages land here
├── temp\                          🔒 pip / uv / session temp caches
├── scripts\                       chat.py, pick-gguf.py
├── setup.ps1                      ← the ONE command to open a working terminal
├── run-model.ps1                  ← interactive: provider → model → chat/server
├── download-model.ps1             ← paste any repo id → auto-organised folder
├── install-torch.ps1              ← torch CPU/GPU into the venv (never global)
├── serve-local.ps1                ← hf / llama / ollama → localhost API server
├── GUIDE.md · AGENTS.md           ← full human guide · agent rulebook
└── README.md                      ← you are here
```
🔒 = hidden from Explorer and `.gitignore`d; **models are plain real files (no symlinks/blobs!) so a folder copy moves everything**.

---

## ⚡ Quick start

> Prereq: any recent Python on the machine (only the tiny interpreter) — everything else lives on this drive.

```powershell
cd E:\abhijeet\huggingface
. .\setup.ps1                        # activate venv + redirect all caches to this drive

# ── get a model (just paste a repo id) ──
.\download-model.ps1 Qwen/Qwen3-4B                       # safetensors → all files
.\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF            # GGUF → auto-picks Q4_K_M + mmproj

# ── run it (2 prompts: engine, then model) ──
.\run-model.ps1
```

---

## 🧾 Environment variables (set once, try `setx`)

All point **into this folder** — permanent user-level registry entries:

| Variable | Value |
|---|---|
| `HF_HOME` | `E:\abhijeet\huggingface\models\huggingface` |
| `HF_HUB_CACHE` | `…\models\huggingface\hub` |
| `HF_XET_CACHE` | `…\models\huggingface\xet` |
| `PIP_CACHE_DIR` | `…\temp\pip` |
| `UV_CACHE_DIR` | `…\temp\uv` |
| `OLLAMA_MODELS` | `…\models\ollama` |

Re-apply on another machine (adjust the drive letter, run once):

```powershell
setx HF_HOME       "E:\abhijeet\huggingface\models\huggingface"
setx HF_HUB_CACHE  "E:\abhijeet\huggingface\models\huggingface\hub"
setx HF_XET_CACHE  "E:\abhijeet\huggingface\models\huggingface\xet"
setx PIP_CACHE_DIR "E:\abhijeet\huggingface\temp\pip"
setx UV_CACHE_DIR  "E:\abhijeet\huggingface\temp\uv"
setx OLLAMA_MODELS "E:\abhijeet\huggingface\models\ollama"
```

These also catch `from_pretrained("org/model")`-style auto-downloads — HF-style libraries
(transformers, diffusers, sentence-transformers…) can never land on C:.

---

## 🖥️ Per-machine setup

Copy this whole folder by USB (plain model files just work), then:

<details>
<summary><b>Option A — copy the folder</b> (recommended, near-zero extra download)</summary>

```powershell
cd <drive>\huggingface
python -m venv .venv
. .\setup.ps1
.\install-torch.ps1 cpu           # or gpu — see below
pip install transformers accelerate diffusers huggingface_hub safetensors sentencepiece
```
</details>

<details open>
<summary><b>Option B — fresh install</b></summary>

```powershell
git clone https://github.com/abhi-1288/hugging-face.git
cd hugging-face
# apply the setx block above, then same .venv steps as Option A
```
</details>

### 🐍 PyTorch — CPU vs GPU (per machine, pick ONE)

| | command | size | when |
|---|---|---|---|
| CPU | `.\install-torch.ps1 cpu` | ~250 MB | laptops / no NVIDIA |
| CUDA 12.x | `.\install-torch.ps1 gpu` | ~2.5–3 GB | NVIDIA ≥ 8 GB VRAM |

Check your GPU: `nvidia-smi` · Check installed build: `.\install-torch.ps1 check` · Switch: run the other one (it uninstalls cleanly). The script **refuses to run outside this folder's venv** — your global Python is untouchable.

---

## 📥 Downloading models

### HuggingFace → `models\huggingface\<org>\<model>\`

```powershell
.\download-model.ps1 Qwen/Qwen3-4B                    # full repo (whatever it is)
.\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF         # GGUF: auto-quant + mmproj ✓
.\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF -Include "*Q8_0*"   # choose quant
hf download mistralai/Mistral-7B-Instruct-v0.3        # plain CLI → hub\ cache (still on E:)
```

Auto-sense covers you: **GGUF repos pick the best default quant** (Q4_K_M → Q4_K_S → Q4_0 → Q5_K_M → Q6_K → Q8_0 → F16) + one mmproj file for vision models. A size guard **refuses anything bigger than free space** (yes, checking you didn't paste a 1 TB model 😅) — override with `-Force` if you have the space.

### Ollama → `models\ollama\` automatically

```powershell
ollama run hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M
```

### Size cheat-sheet

| model | disk |
|---|---|
| LiquidAI/LFM3-VL-2B-GGUF `Q4_K_M` | ~1 GB |
| Qwen/Qwen3-4B (safetensors) | ~8 GB |
| mistralai/Mistral-7B-Instruct-v0.3 | ~14.5 GB |
| Qwen/Qwen3-32B | ~65 GB ⚠ check free space |
| openai/whisper-large-v3 | ~3 GB |
| runwayml/stable-diffusion-v1-5 | ~5 GB |

---

## 🚀 Running models

### Interactive (no code)

```powershell
.\run-model.ps1
```
```text
Which provider?    1) huggingface   2) ollama          ← "ollama" checks it's installed!
Which model?       [0] liquidai/lfm3-vl-2b-gguf  [1] qwen/qwen3-4b  (skips if only one)
How?               1) chat (terminal)   2) server (localhost API for agents)
```

### In code

```python
from transformers import pipeline
pipe = pipeline("text-generation", model=r"E:\abhijeet\huggingface\models\huggingface\qwen\qwen3-4b")
```

```python
# any library/model type, auto-stored on this drive:
from transformers import pipeline
pipeline("automatic-speech-recognition", model="openai/whisper-large-v3")("audio.mp3")
from diffusers import StableDiffusionPipeline
StableDiffusionPipeline.from_pretrained("runwayml/stable-diffusion-v1-5")("a parrot").images[0].save("out.png")
```

---

## 🤖 Use it as an AI provider (for agents)

This drive runs **real OpenAI-compatible localhost APIs** — verified working:

✅ **HF engine** → `transformers serve` on `:8000/v1` (loads Qwen3-4B from this drive)
✅ **llama.cpp** → `llama-server` on `:8080/v1` (31 tok/s CPU with the 2B GGUF, faster with `-ngl 99` GPU)
🦙 **Ollama** → `:11434/v1` (once Ollama is installed; models still land on this drive)

```powershell
.\serve-local.ps1 hf        # or: llama / ollama      → full guide in AGENTS.md
```

### OpenCode

```json
{
  "provider": {
    "local-hf": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local HF (transformers serve)",
      "options": { "baseURL": "http://localhost:8000/v1" },
      "models": { "qwen3-4b": { "name": "Qwen3-4B (local)" } }
    },
    "local-llamacpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local llama.cpp",
      "options": { "baseURL": "http://localhost:8080/v1" },
      "models": { "local": { "name": "whichever gguf is loaded" } }
    },
    "local-ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local Ollama",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M": { "name": "LFM3-VL-2B (local)" } }
    }
  }
}
```

### Curl test

```powershell
curl.exe http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" `
  -d '{"max_tokens":200,"messages":[{"role":"user","content":"hi"}]}'
```

> 🧀 **Qwen3 thinking mode:** it reasons before answering — set `max_tokens` ≥ 200 or disable with `"chat_template_kwargs": {"enable_thinking": false}`.
> **Claude Code** speaks Anthropic's format → bridge via `litellm --port 4000` (details in [AGENTS.md](AGENTS.md)).
> Stop servers: see the bottom of [AGENTS.md](AGENTS.md).

---

## 🩺 Troubleshooting

| symptom | fix |
|---|---|
| `F:\…\HF-Cache` / dead-drive-letter cache errors | stale env vars from an old install → re-run the `setx` block, **close ALL terminals** and reopen (here `setup.ps1` fixes it per-run anyway) |
| `pip` going to global Python on C: | venv wasn't active → `. .\setup.ps1` (dot + space matters). Verify: `pip -V` shows `E:\abhijeet\huggingface\.venv` |
| port already in use (WinError 10048) | old server still alive → `Get-NetTCPConnection -LocalPort <port> \| %{ Stop-Process -Id $_.OwningProcess -Force }` |
| `transformers serve` says "raw GGUF" | GGUFs belong to the llama.cpp engine → `.\serve-local.ps1 llama` |
| drive unexpectedly growing | see what's eating it: `Get-ChildItem models -Recurse \| Measure-Object Length -Sum` |
| empty `content` from Qwen | it spent tokens thinking → bigger `max_tokens` or disable thinking (see agent section) |

---

<div align="center">

**Made to be portable** — clone it, copy it, take it anywhere. 🚗
Repo: [`abhi-1288/hugging-face`](https://github.com/abhi-1288/hugging-face)

</div>
