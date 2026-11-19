# 2026-11-18｜World4Scorer 本机环境预检

- **运行编号**：`2026-11-18_world4scorer_env`（日期按 Asia/Shanghai）
- **目的**：在本机 Ubuntu 上验证 RTX 5060 Laptop 的 CUDA 运算，并建立与 CommonRoad、ROS 隔离的 World4Scorer 推理环境。
- **结论**：环境预检通过，**不代表 E0 或基线复现通过**。

## 环境与处理过程

最初 PCI 能枚举显卡，但没有 NVIDIA 驱动绑定，`nouveau` 报 `unknown chipset`，`nvidia-smi` 和 `libcuda.so.1` 均不可用。重新检查时，Ubuntu 官方源的 `nvidia-driver-595-open` 及当前内核对应的预编译模块已安装，`nvidia` 驱动已绑定。`nvidia-smi` 报告驱动 `595.99.02`、显存 `8151 MiB`，CUDA 驱动接口 `cuInit(0)` 返回 `0`。

使用 `$HOME/.venvs/world4scorer`（Python `3.10.12`），锁定 `torch==2.12.0`、`torchvision==0.27.0`、`numpy==1.26.4`；实测导入的是 `torch 2.12.0+cu130` 与 `torchvision 0.27.0+cu130`，CUDA 运行时为 `13.0`。这是本机适配组合，不是作者原始 `torch 2.1.2 + cu121` 环境。将 World4Scorer 固定在 `7814310e0bd65c6e21f06b81eedfec2ac9a06aa9`，从该提交可编辑安装 World4Scorer 自带的 NAVSIM `1.1.0` 与其随附的 nuPlan devkit `1.2.2`；未安装或验证正式评分用的独立 NAVSIM v2.2 环境。

## 验证结果

| 验证项 | 验收标准 | 实测结果 |
| --- | --- | --- |
| PyTorch GPU 运算 | 两个 `128 × 128` 的 FP32 全 1 矩阵在 `cuda:0` 上相乘，同步后逐元素校验 | 通过；设备算力 `(12, 0)`，结果全部为 `128.0` |
| 环境依赖 | `pip check` 无冲突；模型、Agent 和候选导出模块均可导入 | 通过；`DrivoRModel`、`DrivoRAgent`、`PoolDumpModule` 导入成功 |
| 作者无权重构建检查 | `tools/verify_release.py --count-params` 预期 `35,520,926` 个参数 | 通过；实测 `35,520,926`，输出 `ALL OK` |

## 复查与证据

在毕设仓库根目录运行（只复查现有环境，不安装依赖、不下载权重或数据）：

```bash
bash experiments/2026-11-18_world4scorer_env/command.sh
```

- [运行清单](manifest.json) · [环境信息](env.txt) · [冻结依赖](requirements-frozen.txt)
- [GPU 原始输出](gpu-smoke.log) · [World4Scorer 检查输出](world4scorer-smoke.log)（源码绝对路径替换为 `$W4S_ROOT`）

**未执行**：未下载发布权重或 NAVSIM 数据，未校验权重文件、未加载 checkpoint、未运行真实样本推理、候选导出、NAVSIM v2.2 评分或 E0。没有评测 token 或成绩，不计入任何基线结果。

已创建独立的 World4Scorer 推理环境：`/home/ybw2204/.venvs/world4scorer`。PyTorch 已在本机 RTX 5060 Laptop GPU 上完成实际运算：在 cuda:0 上执行了 128×128 矩阵乘法，同步后逐元素核对，结果全部为预期的 128.0。
- 环境：Python 3.10.12，PyTorch 2.12.0+cu130，CUDA 运行时 13.0。
- 源码：已固定 World4Scorer 提交 7814310，并安装随附的 nuPlan devkit。
- 兼容性：`pip check` 通过，模型、Agent 和候选导出模块均可导入。作者的无权重构建检查通过，参数量为 35,520,926，与预期一致。
使用时隔离 ROS 和用户级 Python 路径：

```bash
source /home/ybw2204/.venvs/world4scorer/bin/activate
unset PYTHONPATH
export PYTHONNOUSERSITE=1
```
