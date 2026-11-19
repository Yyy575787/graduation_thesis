## 1. 建独立 navsim_v2 环境
你的 $HOME/.venvs/world4scorer 装的是 NAVSIM 1.1.0，因此需要另建一个隔离环境专门跑官方 v2.2 缓存与评分：

拉取 navsim v2.2 并建环境：

```bash
mkdir -p ~/navsim_workspace/{exp,dataset/maps,dataset/navsim_logs,dataset/sensor_blobs}
cd ~/navsim_workspace
git clone -b v2.2 https://github.com/autonomousvision/navsim.git
python3 -m venv ~/.venvs/navsim_v2
source ~/.venvs/navsim_v2/bin/activate
pip install -e ~/navsim_workspace/navsim
```
以后可在独立终端运行 NAVSIM，避免继承 ROS 路径：
```bash
source /home/ybw2204/.venvs/navsim_v2/bin/activate
unset PYTHONPATH
export PYTHONNOUSERSITE=1
python -m pip check
```

## 2. 下载地图与 mini 分片
下载前
```bash
(navsim_v2) ybw2204@Legion:~/navsim_workspace$ df -h
文件系统        大小  已用  可用 已用% 挂载点
/dev/nvme0n1p7  195G   92G   93G   50% /
```

| 下载的内容 | 有什么用 | 位置 |
|---|---|---|
| **nuPlan 高精地图** | 提供车道、路口、可行驶区域等静态信息。主要给 **NAVSIM 评测器**用，比如检查候选轨迹是否驶出可行驶区域、沿路线前进了多少。[NAVSIM 评分指标](https://github.com/autonomousvision/navsim/blob/v2.2/docs/metrics.md) | /home/ybw2204/navsim_workspace/dataset/maps |
| **`mini` 元数据** | 是结构化的驾驶日志，不是图片。它把时间、相机文件、自车位置和速度、周围车辆轨迹、信号灯状态对应起来。推理时只给模型当前可用的自车状态和导航信息；日志里的未来信息留给评测，不提前喂给模型。 | /home/ybw2204/navsim_workspace/dataset/navsim_logs/mini |
| **`mini` 相机第 0 分片** | 是一批真实道路图片。当前 World4Scorer 配置读取前、左、右、后四路，用来生成候选轨迹并给它们打分。**第 0 分片是数据包编号，不是第 0 路相机**；只下载它，就只覆盖部分日志。[官方分片脚本](https://github.com/autonomousvision/navsim/blob/v2.2/download/download_mini.sh) | /home/ybw2204/navsim_workspace/dataset/sensor_blobs/mini |

**下载并校验两份权重**：World4Scorer 的 `w4s_navsim_ep23.ckpt` 和 DINOv2 的 `model.safetensors` 已校验

## 3. T03｜138 个 `mini` 样本推理与评分（2026-11-19）

**结论：评分缓存、GPU 候选导出、CPU 推演和两组评分均覆盖 138/138；本批没有相邻帧对，未验证 `lam1` 的实际重排效果。** 本次为 `mini` 小样本联调，不是正式 `navtest` 成绩。

- **运行编号**：`t03-mini138-2026-11-19`。为避免往仓库写入大型缓存和 pickle，原始产物保存在本机 `$HOME/navsim_workspace/exp/t03-mini138-2026-11-19/`。
- **样本**：相机第 0 分片的 2 份日志，分别 58 和 80 个 token，固定于 `split.json`（SHA-256：`1c2eeff94901d0bda6f91fa9ba9c89811185cb9750f7bdb8454f469a71e64c13`）。缓存、候选池、仿真、提交文件和有效评分分别核对了 token 集合；未用总行数代替匹配检查。
- **执行环境**：评分用 NAVSIM `v2.2`（`359c7f72304bfa8273e754224a213d3751bd2340`）、Python 3.10.12、CPU 顺序缓存 / 单分片；推理用 World4Scorer（`7814310e0bd65c6e21f06b81eedfec2ac9a06aa9`）、PyTorch `2.12.0+cu130`、RTX 5060 Laptop、`batch_size=1`、`num_workers=0`。两环境分别执行，隔离 ROS 路径，未修改两份上游源码。
- **权重 SHA-256**：World4Scorer `22604f83dda8a2bd2dd05356fca8457f0c7dc78439f47db396e5c85d74971a44`；DINOv2 `dca70548ecd7b03ffba6172c4db403014511b5ee6073f9fca72ba9e6e602a25d`。作者校验脚本输出 `ALL OK`，本次推理实际加载两份权重。

### 分段耗时和磁盘占用

耗时是 `/usr/bin/time` 的墙钟时间，包含进程启动和读写；磁盘占用按 `du -sB1` 统计。

| 阶段 | 耗时 | 产物占用 | 实测结果 |
| --- | ---: | ---: | --- |
| NAVSIM v2.2 评分缓存 | 80.00 s | `metric_cache/` 46.04 MiB | 138/138 成功，0 失败；峰值 RSS 约 614 MiB |
| World4Scorer GPU 推理与导出 | 96.10 s | `pool.pkl` 1.08 MiB（文件 1,132,478 字节） | 138/138；每个样本有 64 条 8 点候选，形状 `(64, 8, 3)` |
| CPU LQR 推演 | 29.22 s | `sims/` 30.41 MiB | 138/138，合计 8,832 条候选推演 |
| CPU 重排序与提交导出 | 2.17 s | `subs/` 56 KiB | 两组均提交 138 个 token，`lam1` 改选 0 条 |
| CPU `lam0` 评分与聚合 | 22.51 s | `score_lam0/` 712 KiB | 138/138 有效，缺缓存 0，失败 0 |
| CPU `lam1` 评分与聚合 | 23.31 s | `score_lam1/` 712 KiB | 138/138 有效，缺缓存 0，失败 0 |

- **GPU 显存**：`nvidia-smi` 每 200 ms 采样，全卡占用从启动前 **723 MiB** 到实测峰值 **1,489 MiB**（差值 766 MiB，不是进程独占显存）。同配置复跑耗时 **95.79 s**；138/138 输出形状及选中编号一致，两次 `pool.pkl` 的 SHA-256 相同。
- **CPU 推演、重排和两组评分合计 77.21 s**，其中纯评分与聚合 45.82 s。不含缓存、GPU 推理或复跑。
- **容量估算**：缓存实测 48,271,360 字节；按 `48,271,360 ÷ 138 × 12,146` 线性外推约 **3.96 GiB（4.25 GB）**。这是缓存单项的基于 `mini` 的估算，不包括数据集、压缩包、中间文件或磁盘余量，也不是 `navtest` 的实测值。下载的地图和 `mini` 数据压缩包合计约 4.67 GiB，解压数据约 5.63 GiB，不含权重和运行产物；运行后根分区仍有约 83 GiB。

### 评分和适用范围

| 方法 | 有效评分 | 小样本 EPDMS（0–100） | 相邻帧对 / 改选 |
| --- | ---: | ---: | --- |
| `lam0` | 138/138（100%） | 69.866 | 0 / 0 |
| `lam1` | 138/138（100%） | 69.866 | 0 / 0 |

固定清单用非重叠窗口抽样，同日志相邻选中样本最小间隔约 7.0 s，不满足评分器的 0.55 s 配对阈值。原版 v2.2 聚合在零对时会报 `ValueError: No objects to concatenate`，已在本次 138 行上复现。仅在这次运行目录用 `aggregate-mini.py` 处理空配对，把跨帧舒适性（EC）保留为缺失，并沿用 v2.2 的缺失 EC 权重归一化；逐样本评分器和上游源码不变。两组提交文件与评分 CSV 分别完全一致，**不能据此判断重排序是否有效**。要检验重排序行为，应另建相邻帧清单，不改本次的 138 个样本。

### 关键日志与复现入口

```text
Completed dataset caching! All 138 features and targets were cached successfully.
POOL_DUMP_SHAPES proposals (64, 8, 3) subscores (64, 6) pdm (64,)
POOL_DUMP_DONE tokens=138
SHARD_DONE idx=0 ntok=138 dt=27s
loaded: sims=138 dump=138 pairs=0 in 0s
SHARD_DONE idx=0 count=1 rows=138 missing_cache=0   # lam0 与 lam1 均为此结果
Number of successful scenarios: 138.
Number of failed scenarios: 0.
Final average score of valid results: 0.6986596520987709.
```

运行目录中保留了 `env.txt`、`split.json`、`results.json`、两个评分目录的逐 token CSV、`*.log`、`*.time.txt`、`*.command.txt` 和原始显存采样 `gpu-pool.nvidia-smi.csv`。复跑脚本为 `cache.sh`、`gpu.sh`、`cpu.sh`；复现实验时把脚本、`split.json` 和两个 `*.hydra.txt` 选择清单复制到同一 `exp` 下的**新运行目录**，按该顺序运行，再用 `summarize.py` 核对覆盖率。评分使用 `non_reactive`，未运行正式全量评测。
