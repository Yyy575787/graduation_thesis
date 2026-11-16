#!/usr/bin/env bash
# 在 Ubuntu 22.04 上搭建 CommonRoad Reactive Planner 环境并跑通第一个官方示例。
#
# 用法（在 Ubuntu 终端里）：
#   bash scripts/ubuntu_setup.sh            # 装环境 + 跑示例 + 归档证据
#   bash scripts/ubuntu_setup.sh --setup-only   # 只装环境，不跑
#
# 说明：
#   - Windows 装不了 commonroad-drivability-checker（PyPI 只有源码包，且包内文件名含
#     Win32 非法字符 ':'），所以规划实验必须在本机 Ubuntu 分区里做。
#   - 代码仓库放在 /mnt/d（Windows 能同时看到），虚拟环境放在 Linux 家目录（速度快）。
set -euo pipefail

WS="/mnt/d/ybw/graduation_thesis"
REPO="$WS/third_party/commonroad-reactive-planner"
VENV="$HOME/.venvs/cr-rp"
EVID="$WS/experiments/2026-11-16_baseline"
MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
SETUP_ONLY="${1:-}"

echo "== 1/5 检查 Python =="
if ! command -v python3 >/dev/null 2>&1; then
  echo "错误：没有 python3。先执行：sudo apt update && sudo apt install -y python3 python3-venv"
  exit 1
fi
PYVER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
echo "python3 = $PYVER"
case "$PYVER" in
  3.9|3.10|3.11) ;;
  *) echo "错误：本项目要求 Python >=3.9,<3.12，当前 $PYVER。"
     echo "      用 sudo apt install -y python3.10-venv && python3.10 -m venv $VENV 指定版本。"
     exit 1 ;;
esac

if [ ! -d "$REPO" ]; then
  echo "错误：找不到仓库 $REPO"
  echo "      在 Windows 上确认 D:\\ybw\\graduation_thesis\\third_party\\commonroad-reactive-planner 存在，"
  echo "      并在 Ubuntu 里检查 /mnt/d 是否已挂载（ls /mnt/d）。"
  exit 1
fi

echo "== 2/5 创建虚拟环境 =="
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV" || { echo "创建失败。可能需要：sudo apt install -y python3-venv"; exit 1; }
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo "== 3/5 安装依赖（清华镜像，约 5–15 分钟）=="
python -m pip install -q -U pip -i "$MIRROR"
python -m pip install -e "$REPO" -i "$MIRROR"

echo "== 4/5 归档环境记录 =="
mkdir -p "$EVID"
{
  echo "# 环境记录（自动生成）"
  echo "生成时间：$(date -Iseconds)"
  echo
  echo "## 操作系统"
  (lsb_release -a 2>/dev/null || cat /etc/os-release) | sed '/^$/d'
  echo
  echo "## 内核"
  uname -srm
  echo
  echo "## Python"
  python --version
  echo
  echo "## 规划器版本"
  echo "仓库：$REPO"
  echo "commit SHA：$(git -C "$REPO" rev-parse HEAD)"
  echo "commit 时间：$(git -C "$REPO" log -1 --format=%cI)"
  echo
  echo "## 硬件"
  lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core' || true
  free -h | head -2
} > "$EVID/env.txt"
python -m pip freeze > "$EVID/requirements-frozen.txt"
echo "已写入 $EVID/env.txt 与 requirements-frozen.txt"

if [ "$SETUP_ONLY" = "--setup-only" ]; then
  echo "== 完成（仅环境）。跑示例：bash scripts/ubuntu_setup.sh =="
  exit 0
fi

echo "== 5/5 跑官方示例 ZAM_Over-1_1 =="
cd "$REPO"
export MPLBACKEND=Agg
set +e
python run_planner.py 2>&1 | tee "$EVID/run_baseline.log"
RC=${PIPESTATUS[0]}
set -e
echo "退出码：$RC"

# 保存场景与配置，保证证据可追溯
cp "example_scenarios/ZAM_Over-1_1.xml" "$EVID/" 2>/dev/null || true
cp "configurations/ZAM_Over-1_1.yaml" "$EVID/" 2>/dev/null || true
if [ -d output ]; then
  rm -rf "$EVID/output"
  cp -r output "$EVID/output"
  echo "已归档 output/ → $EVID/output"
fi

echo
echo "== 下一步 =="
echo "1. 打开 $EVID/env.txt 和 run_baseline.log，确认最后没有异常。"
echo "2. 再跑一次同样的命令，对比两次日志的最终时间步是否一致（复现检查）。"
echo "3. 把结论填进 $EVID/README.md。"
exit "$RC"
