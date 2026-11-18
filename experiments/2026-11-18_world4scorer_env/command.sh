#!/usr/bin/env bash
set -euo pipefail

# Recheck the recorded environment without installing packages or loading weights.
record_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
w4s_root=${W4S_ROOT:-"$record_dir/../../third_party/World4Scorer"}
python=${W4S_PYTHON:-"$HOME/.venvs/world4scorer/bin/python"}
expected_commit=7814310e0bd65c6e21f06b81eedfec2ac9a06aa9

if [[ $(git -C "$w4s_root" rev-parse HEAD) != "$expected_commit" ]]; then
  printf 'Expected World4Scorer commit %s\n' "$expected_commit" >&2
  exit 1
fi

unset PYTHONPATH
export PYTHONNOUSERSITE=1 HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
export W4S_ROOT=$(cd -- "$w4s_root" && pwd)

nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
"$python" -m pip --disable-pip-version-check check
"$python" -B - <<'PY'
import os
from pathlib import Path

import navsim
import nuplan
import torch
import torchvision
from navsim.agents.drivoR.drivor_agent import DrivoRAgent
from navsim.agents.drivoR.drivor_model import DrivoRModel
from navsim.planning.script.run_pool_dump import PoolDumpModule

root = Path(os.environ["W4S_ROOT"])
assert Path(navsim.__file__).resolve().parent == root / "navsim"
assert Path(nuplan.__file__).resolve().parent == root / "nuplan-devkit" / "nuplan"
print("imports:", DrivoRModel.__name__, DrivoRAgent.__name__, PoolDumpModule.__name__)
print("torch/torchvision:", torch.__version__, torchvision.__version__)
assert torch.cuda.is_available(), "PyTorch cannot initialize CUDA"
x = torch.ones((128, 128), dtype=torch.float32, device="cuda:0")
y = x @ x
torch.cuda.synchronize()
assert y.is_cuda and y.device.index == 0
assert torch.equal(y.cpu(), torch.full((128, 128), 128.0))
print("GPU matmul: PASS", y.device, tuple(y.shape), "all values 128.0")
PY
"$python" -B "$W4S_ROOT/tools/verify_release.py" --count-params
