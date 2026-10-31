#!/usr/bin/env python3
"""Prints the file-pattern(s) to download for a GGUF repo: the first available
quant in a sensible preference order, plus the mmproj file for multimodal repos."""
import fnmatch
import sys

from huggingface_hub import list_repo_files

repo = sys.argv[1]
prefs = ["*Q4_K_M*", "*Q4_K_S*", "*Q4_0*", "*Q5_K_M*", "*Q6_K*", "*Q8_0*", "*F16*"]
files = sorted(list_repo_files(repo))

chosen = []
for pat in prefs:
    hits = [f for f in files if fnmatch.fnmatch(f.lower(), pat.lower()) and not f.startswith(".")]
    if hits:
        chosen = hits
        break
if not chosen:
    chosen = [f for f in files if f.lower().endswith(".gguf")] or files[:1]

extra = []
mm = [f for f in files if fnmatch.fnmatch(f.lower(), "*mmproj*") and not f.startswith(".")]
for pat in ["*Q8_0*", "*F16*", "*"]:
    hits = [f for f in mm if fnmatch.fnmatch(f.lower(), pat.lower())]
    if hits:
        extra = hits[:1]
        break
print("|".join(chosen + extra))
