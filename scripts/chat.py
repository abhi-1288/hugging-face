# chat.py - interactive chat with a locally downloaded model (flat folder).
# Usage:  . .\setup.ps1   then   python scripts\chat.py
# Default model: the Qwen3-4B folder in this drive, if present.
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODELS_ROOT = ROOT / "models" / "huggingface"

def find_model_dir():
    # accepts:  "Qwen/Qwen3-4B", "qwen/qwen3-4b", "qwen3-4b", or a direct path
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        p = Path(arg)
        if p.is_dir():
            return p
        arg_l = arg.lower()
        parts = arg_l.replace("\\", "/").split("/")
        if len(parts) >= 2:
            candidates = ROOT.glob(f"models/huggingface/{parts[-2]}/{parts[-1]}")
        else:
            candidates = MODELS_ROOT.glob(f"*/{parts[0]}")
        candidates = list(candidates)
        if candidates:
            return candidates[0]
        sys.exit(f"Model folder not found for: {arg}. Download it with:\n"
                 "  .\\download-model.ps1 " + arg)
    candidates = list(MODELS_ROOT.glob("*/*"))
    if not candidates:
        sys.exit("No models found in models\\huggingface\\. Download one with:\n"
                 "  .\\download-model.ps1 Qwen/Qwen3-4B")
    return candidates[0]

model_dir = find_model_dir()
print(f"Loading model from: {model_dir}", flush=True)

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.bfloat16 if device == "cuda" else torch.float32
print(f"Device: {device}  (set device via GPU torch, see GUIDE.md section 2)", flush=True)

tok = AutoTokenizer.from_pretrained(str(model_dir))
model = AutoModelForCausalLM.from_pretrained(str(model_dir), dtype=dtype).to(device)
model.eval()

print("Chat ready. Type your message (Ctrl+C to quit).", flush=True)
messages = [{"role": "system", "content": "You are a helpful assistant."}]
while True:
    try:
        user = input("\nYou: ").strip()
    except (KeyboardInterrupt, EOFError):
        break
    if not user:
        continue
    messages.append({"role": "user", "content": user})
    prompt = tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tok(prompt, return_tensors="pt").to(device)
    with torch.no_grad():
        out = model.generate(**inputs, max_new_tokens=512, do_sample=True, temperature=0.7, top_p=0.8)
    reply = tok.decode(out[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)
    messages.append({"role": "assistant", "content": reply})
    print(f"Assistant: {reply}")
