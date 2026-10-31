# HuggingFace Local Models — Master Guide

**Everything lives on this drive (`E:\abhijeet\huggingface`) — Python packages, model
weights, caches, tools. Nothing installs to `C:`.**

Folder layout:

```
E:\abhijeet\huggingface\
├── .venv\                          ← Python environment + all libraries (hidden)
├── models\
│   ├── huggingface\                ← HF models, per org/model:
│   │   ├── qwen\qwen3-4b\
│   │   └── liquidai\lfm3-vl-2b-gguf\
│   │   (plus its own hub\ and xet\ subfolders = HF auto-cache, from_pretrained)
│   └── ollama\                     ← Ollama's model storage (its own blobs layout)
├── tools\                          ← llama.cpp portable (GGUF inference, hidden)
├── temp\                           ← pip / uv / session temp (hidden)
├── scripts\                        ← ready-made run scripts (chat.py ...)
├── setup.ps1                       ← open a working terminal
├── download-model.ps1             ← HF downloader (org\model flat folders)
└── GUIDE.md                        ← this file
```

---

## 0. Environment variables (already set permanently on this user — registry)

| Variable | Value |
|---|---|
| `HF_HOME` | `E:\abhijeet\huggingface\models\huggingface` |
| `HF_HUB_CACHE` | `E:\abhijeet\huggingface\models\huggingface\hub` |
| `HF_XET_CACHE` | `E:\abhijeet\huggingface\models\huggingface\xet` |
| `PIP_CACHE_DIR` | `E:\abhijeet\huggingface\temp\pip` |
| `UV_CACHE_DIR` | `E:\abhijeet\huggingface\temp\uv` |
| `OLLAMA_MODELS` | `E:\abhijeet\huggingface\models\ollama` |

On another machine (adjust drive letter, run once):

```powershell
setx HF_HOME       "E:\abhijeet\huggingface\models\huggingface"
setx HF_HUB_CACHE  "E:\abhijeet\huggingface\models\huggingface\hub"
setx HF_XET_CACHE  "E:\abhijeet\huggingface\models\huggingface\xet"
setx PIP_CACHE_DIR "E:\abhijeet\huggingface\temp\pip"
setx UV_CACHE_DIR  "E:\abhijeet\huggingface\temp\uv"
setx OLLAMA_MODELS "E:\abhijeet\huggingface\models\ollama"
```

> These also catch `from_pretrained("Qwen/Qwen3-4B")` style auto-downloads (into
> `models\huggingface\hub\`), torches/diffusers/whisper — all HF-style libraries.

---

## 1. One-time setup per machine

### Option A — copy this whole folder by USB (nothing else to download)

Model folders are plain files → they just work after copying. If `.venv` breaks
(venvs hardcode an interpreter path), recreate it with the machine's Python:

```powershell
cd E:\abhijeet\huggingface
python -m venv .venv
. .\setup.ps1
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install transformers accelerate diffusers huggingface_hub safetensors sentencepiece
```

### Option B — fresh from internet, same commands.

---

## 2. PyTorch — CPU vs GPU (pick ONE per machine)

First check what GPU the machine has:  `nvidia-smi`

```powershell
# CPU (small ~250 MB, works on every machine):
.\install-torch.ps1 cpu

# CUDA 12.x (big ~2.5-3 GB, much faster, needs NVIDIA):
.\install-torch.ps1 gpu

# show which build is active:
.\install-torch.ps1 check

# manual equivalent after '. .\setup.ps1' (venv active = safe):
pip install torch --index-url https://download.pytorch.org/whl/cpu

# verify:
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

Switch with `pip uninstall torch -y` then the other index.

---

## 3. Downloading models

### HuggingFace (any repo) → `models\huggingface\<org>\<model>\`

```powershell
# simplest — paste ANY repo id, auto-sensed: flat folder, and for GGUF repos it
# auto-picks the first sensible quant (Q4_K_M > ... > F16) + mmproj automatically:
.\download-model.ps1 Qwen/Qwen3-4B
.\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF          # -> lfm3-vl-2b-gguf ...Q4_K_M.gguf

# choose the quant yourself:
.\download-model.ps1 LiquidAI/LFM3-VL-2B-GGUF -Include "*Q8_0*"

# straight CLI also works (goes to models\huggingface\hub\ auto-cache):
hf download mistralai/Mistral-7B-Instruct-v0.3

# see all files in a repo first:
python -c "from huggingface_hub import list_repo_files; [print(f) for f in list_repo_files('LiquidAI/LFM3-VL-2B-GGUF')]"
```

The downloader checks free disk space first and **refuses models that won't fit**
(watch out: some repo examples are 1T+ param models = **1 TB+**). `-Force` overrides.

### Ollama GGUF → `models\ollama\` automatically

```powershell
ollama run hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M       # downloads into E: (OLLAMA_MODELS)
ollama run hf.co/<anything-on-hf-co>:<quant>
```

### Which repo fits your drive?

| model | disk |
|---|---|
| LiquidAI/LFM3-VL-2B-GGUF Q4_K_M | ~1.5 GB |
| Qwen/Qwen3-4B (safetensors) | ~8 GB |
| mistralai/Mistral-7B-Instruct-v0.3 | ~14.5 GB |
| Qwen/Qwen3-32B | ~65 GB (tight!) |
| Whisper large-v3 | ~3 GB |
| Stable Diffusion 1.5 | ~5 GB |

Use **GGUF quants** (`...-GGUF:Q4_K_M`) for big models — Q4_K_M needs ~half the space.

---

## 4. Running models — Python / transformers

Always `. .\setup.ps1` first.

```powershell
# interactive chat, loads models\huggingface\qwen\qwen3-4b\ :
python scripts\chat.py
python scripts\chat.py qwen3-4b        # by name
python scripts\chat.py Qwen/Qwen3-4B   # by repo id

# inline one-shot:
python -c "
from transformers import pipeline
pipe = pipeline('text-generation', model=r'E:\abhijeet\huggingface\models\huggingface\qwen\qwen3-4b')
print(pipe('Hello!')[0]['generated_text'])"

# image gen (diffusers), fully on E: via HF_HOME:
python -c "
from diffusers import StableDiffusionPipeline
import torch
p = StableDiffusionPipeline.from_pretrained('runwayml/stable-diffusion-v1-5').to('cuda' if torch.cuda.is_available() else 'cpu')
p('a colorful parrot').images[0].save(r'E:\abhijeet\huggingface\out.png')"

# whisper:
python -c "
from transformers import pipeline
print(pipeline('automatic-speech-recognition', model='openai/whisper-large-v3')('audio.mp3')['text'])"
```

## 4b. Or with the low-level Ollama-like style (no install)

`hf download` + `scripts\chat.py` ≈ is your "run by id":

```powershell
.\download-model.ps1 mistralai/Mistral-7B-Instruct-v0.3
python scripts\chat.py mistralai/Mistral-7B-Instruct-v0.3
```

---

## 5. Running GGUF — llama.cpp (no Ollama needed)

`tools\` is portable — GGUFs don't need torch at all.

```powershell
tools\llama.cpp-cuda\llama-server.exe -m models\huggingface\liquidai\lfm3-vl-2b-gguf\<file>.gguf -ngl 99 -c 4096
# then open http://localhost:8080 (OpenAI-compatible)
```

`-ngl 99` = all layers on GPU; `-ngl 0` = pure CPU (laptops). Missing-CUDA error →
install the `llama-...-bin-win-cpu-x64.zip` build (see section 7).

---

## 6. Ollama (optional)

The Ollama *installer* goes to C: (~4 GB, unavoidable). All its **models** store in
`models\ollama\` (E:) thanks to `OLLAMA_MODELS`. If strict "nothing on C:" → skip
section 6, use section 5.

---

## 7. Per-machine notes

| situation | torch | llama.cpp |
|---|---|---|
| laptop, no NVIDIA | `/cpu` index | `llama-...-bin-win-cpu-x64.zip` from releases, `-ngl 0` |
| NVIDIA ≥ 8 GB | `/cu128` | `llama-...-bin-win-cuda-12.4-x64.zip` + `cudart-...zip` (already in tools\) |

---

## 8. Troubleshooting

- **`F:\HuggingFace\HF-Cache` errors** → stale env vars from an old setup on a dead
  drive. Fix: re-run section 0 `setx` commands, **close ALL terminals** (env vars load
  at process start), reopen. In this folder everything is always corrected by
  `setup.ps1`/`download-model.ps1` per-run regardless.
- **pip installed to global Python on C:** → venv not active. `. .\setup.ps1`
  (dot + space matters). Verify: `pip -V` → `E:\abhijeet\huggingface\.venv\...`
- **Where did my disk go?** → `Get-ChildItem models -Recurse -Directory -Filter "*"`
- **drive letter changed on other machines** → fixed by section 0 re-run.
- **verified model IDs to try:** `Qwen/Qwen3-4B`, `LiquidAI/LFM3-VL-2B-GGUF`,
  `mistralai/Mistral-7B-Instruct-v0.3`, `openai/whisper-large-v3`,
  `runwayml/stable-diffusion-v1-5`
