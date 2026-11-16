# 第三方源码

不纳入版本库（见 `.gitignore`），按下表记录的版本重新克隆即可复现。

| 仓库 | 用途 | 固定 commit | 克隆位置 |
|---|---|---|---|
| [CommonRoad/commonroad-reactive-planner](https://github.com/CommonRoad/commonroad-reactive-planner) | 规划基线（B0） | `6f2f0d91d4b9370f8e716349833308271365e7d1`（2025-03-03） | `third_party/commonroad-reactive-planner` |

重新克隆：

```bash
git clone https://github.com/CommonRoad/commonroad-reactive-planner.git third_party/commonroad-reactive-planner
git -C third_party/commonroad-reactive-planner checkout 6f2f0d91d4b9370f8e716349833308271365e7d1
```

升级版本时：改本文件的 commit、在 `CHANGELOG.md` 记一条、重跑全部基线对照。论文中同时写版本号与 commit SHA。

## 平台限制（2026-11-16 实测）

- **Windows 不可用**：`commonroad-drivability-checker` 在 PyPI 只有源码包（无 Windows wheel），且包内测试文件名含 `:`，Windows 无法解压，`pip install` 直接失败。
- Python 要求 `>=3.9,<3.12`；Ubuntu 22.04 自带 3.10 满足。原 Windows 上的 `commonroad-py38` 环境版本不符，已弃用。
- 环境搭建与首个示例的运行脚本：[../scripts/ubuntu_setup.sh](../scripts/ubuntu_setup.sh)。
