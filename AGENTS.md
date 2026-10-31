# AGENTS.md — local model servers for AI agents (OpenCode / Claude Code / any OpenAI-compatible client)

This drive (`E:\abhijeet\huggingface`) can act as a **self-contained AI provider**:
any agent app points at a `localhost:.../v1` URL and talks to models stored here.
Nothing leaves the machine, nothing is read from C:.

Three engines, three localhost URLs:

| engine | storage on this drive | server command | OpenAI-compatible endpoint |
|---|---|---|---|
| **transformers/HF** (safetensors) | `models\huggingface\<org>\<model>\` | `. .\setup.ps1; transformers serve` | `http://localhost:8000/v1` |
| **llama.cpp** (GGUF) | `models\huggingface\<org>\<model>\*.gguf` | `tools\llama.cpp-cuda\llama-server.exe -m <gguf>` | `http://localhost:8080/v1` |
| **Ollama** (GGUF) | `models\ollama\` (OLLAMA_MODELS) | `serve-local.ps1 ollama` (needs Ollama installed on the PC) | `http://localhost:11434/v1` |

Start any of them with one script (or `.\run-model.ps1` → answers 2 prompts → runs):

```powershell
. .\setup.ps1
.\run-model.ps1            # interactive: provider -> model -> chat/server
.\serve-local.ps1 hf          # HF engine: serves a transformers model, port 8000
.\serve-local.ps1 llama       # GGUF engine: serves the first GGUF found (or pass a name)
.\serve-local.ps1 ollama      # Ollama engine (checks Ollama is installed, then serves)
```

---

## Rules for the agent (read this, agent!)

1. This drive is isolated. **Never** write outside `E:\abhijeet\huggingface`, never
   `pip install` outside its `.venv`, never touch `C:\Python314` or the user's global pip.
2. Need a model? `.\download-model.ps1 <org>/<repo>` — it lands in
   `models\huggingface\<org>\<model>\` automatically (GGUFs get one sensible quant).
3. Server already running? Check: `curl http://localhost:8000/v1/models` (HF) or
   `:8080/v1/models` (llama.cpp) or `:11434/v1/models` (Ollama). Start only if absent.
4. One GGUF per llama-server process. Ollama/transformers can hot-swap models.

---

## Pointing agents at localhost

### OpenCode (`opencode.json` / `~/.config/opencode/opencode.json`)

```json
{
  "provider": {
    "local-hf": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local HF (transformers serve)",
      "options": { "baseURL": "http://localhost:8000/v1" },
      "models": {
        "qwen3-4b": { "name": "Qwen3-4B (local)" }
      }
    },
    "local-llamacpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local llama.cpp",
      "options": { "baseURL": "http://localhost:8080/v1" },
      "models": {
        "local": { "name": "whichever gguf is loaded" }
      }
    },
    "local-ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local Ollama",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": {
        "hf.co/LiquidAI/LFM3-VL-2B-GGUF:Q4_K_M": { "name": "LFM3-VL-2B Q4_K_M (local)" }
      }
    }
  }
}
```

### Claude Code (anthropic-format CLI — needs OpenAI→Anthropic bridge, or use opencode)

Claude Code speaks the *Anthropic* protocol, not OpenAI. Two options:
- run the model through a 1-lite proxy: `pip install litellm[proxy]` in the venv,
  then `litellm --model http://localhost:8080/v1 --port 4000` and set
  `ANTHROPIC_BASE_URL=http://localhost:4000` + `ANTHROPIC_API_KEY=dummy` for claude code.
- simplest: use OpenCode for local models, keep claude code on its native API.

### curl test (verify before wiring the agent)

```powershell
curl.exe http://localhost:8000/v1/models
curl.exe http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{\"model\":\"qwen3-4b\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}'
```

### python test (any OpenAI client library)

```python
from openai import OpenAI
c = OpenAI(base_url="http://localhost:8000/v1", api_key="none")
print(c.chat.completions.create(model="qwen3-4b", messages=[{"role":"user","content":"hi"}]).choices[0].message.content)
```

---

## Engine notes — VERIFIED working on this drive (2026-10-31)

- **transformers serve** (:8000): boots, loads `models\huggingface\qwen\qwen3-4b` from the
  local folder and completes `/v1/chat/completions` ✓. Two quirks:
  - `/v1/models` lists `[]` when serving a local path — send the **folder path** as the
    `model` field, or leave the model field out and let FORCE_MODEL answer.
  - Qwen3 emits `reasoning_content` (thinking) first; set `max_tokens` ≥ 200 or it
    answers empty. Disable thinking via `"chat_template_kwargs": {"enable_thinking": false}`.
  - Needs `transformers[serving]` extras (already installed in this venv). Default port 8000.
- **llama-server** (:8080): verified ✓ with `LFM3-VL-2B-Q4_K_M.gguf` — model listing
  works, 31 tok/s on pure CPU (`-ngl 0`). Best performance for GGUF; `-ngl 99` on NVIDIA.
  `model` field = full gguf path (also returned by its `/v1/models`).
- **Ollama**: if `ollama` is not installed, `serve-local.ps1 ollama` prints the
  download link instead of failing. Models always land on this drive because
  `OLLAMA_MODELS` points at `models\ollama\`.

### Stop a running server when done

```powershell
Get-NetTCPConnection -LocalPort 8000 | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }   # hf
Get-NetTCPConnection -LocalPort 8080 | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }   # llama.cpp
```
