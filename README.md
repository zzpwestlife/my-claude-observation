# Claude Code 观测系统 (Claude Code Observation)

本项目提供了一套基于 Docker 的本地化监控技术栈，用于收集、存储和可视化展示 Claude Code CLI 的 Token 使用量和预估成本数据。

## 📊 架构与数据流

整个监控系统运行在你本地（macOS/Linux），数据流向如下：

1. **Claude Code (macOS)**: 产生遥测数据，通过 HTTP/JSON OTLP 协议推送至本地端口。
2. **OTel Collector (Docker)**: 接收 OTLP 数据，进行批处理后，通过 Prometheus Remote Write 推送给时序数据库。
3. **VictoriaMetrics (Docker)**: 高性能时序数据库，用于存储监控指标（配置了 1 年的数据保留期）。
4. **Grafana (Docker)**: 读取 VictoriaMetrics 的数据，通过大盘（Dashboard）进行可视化展示。

## 🚀 快速开始

### 1. 前置要求

- `docker` (≥ 20.x) 
- `docker compose` (v2.x)

*推荐使用 OrbStack 或 Podman。*

### 2. 安装与启动

本项目提供了一个极简的交互式安装向导，你只需要在项目根目录下运行一条命令：

```bash
make start
```

如果你是首次运行，系统会自动调起交互式向导，引导你完成：
1. **端口配置**：选择使用默认端口（OTel: 4319, VM: 8428, Grafana: 3001）或自定义端口，并自动生成 `.env` 环境变量文件。
2. **Claude Code 配置自动注入**：自动为 `~/.claude/settings.json` 注入监控所需的遥测环境变量。

> 💡 **提示**：如果向导修改了 Claude 的配置文件，你需要**新开一个终端窗口并重新启动 Claude Code 会话**，配置才能生效。

### 3. 查看大盘

容器启动完成后，在浏览器中访问 Grafana：

- **URL**: `http://localhost:3001` (或你自定义的 Grafana 端口)
- **默认账号**: `admin`
- **默认密码**: `admin`

进入 **Dashboards → Applications → Claude Code Metrics** 即可看到 Token 消耗及花费面板。

---

## 🛠️ 常用命令 (Makefile)

本项目通过 `Makefile` 封装了日常的运维操作，你可以使用以下命令：

| 命令 | 说明 |
| --- | --- |
| `make install` | 仅运行交互式安装向导（不启动容器），用于重新配置端口或刷新配置。 |
| `make start` | 启动监控技术栈（若未配置会自动触发向导），以守护进程模式运行。 |
| `make stop` | 停止所有监控容器（保留数据）。 |
| `make status` | 查看所有容器的当前运行状态。 |
| `make logs` | 实时查看所有容器的运行日志（按 `Ctrl+C` 退出）。 |
| `make clean` | **⚠️ 危险操作**：停止所有容器并删除数据卷（VictoriaMetrics 和 Grafana 数据将清空）。 |

---

## 🔧 常见问题排查 (FAQ)

### 1. Grafana 成功启动，但面板没有数据 (No Data)
- **原因 A（最常见）：** 修改遥测配置后，**没有重启 Claude Code 会话**。Claude Code 是一个长驻进程，不会热加载 `settings.json`。
  - **解决：** 在当前运行 `claude` 的终端中输入 `/exit` 或按 `Ctrl+C` 退出，然后重新运行 `claude`。随便聊两句产生数据后，等待约 15 秒（VictoriaMetrics 刷盘延迟），刷新 Grafana 页面即可。
- **原因 B：** Claude Code 的指标需要 `cumulative` 模式，否则会被 VictoriaMetrics 丢弃。
  - **解决：** 检查 `~/.claude/settings.json` 的 `env` 节点中是否包含 `"OTEL_METRICS_EXPORTER_TEMPORALITY_PREFERENCE": "cumulative"`。如果使用 `make install` 的自动配置，该项会自动添加。

### 2. 终端出现 `Stop hook error: Failed with non-blocking status code: No stderr output` 报错
- **原因：** 如果你修改了 OTel 的端口（比如从默认的 `4318` 改为了 `4319`），虽然更新了 `env` 中的端点配置，但 `settings.json` 中可能还残留着硬编码的 `hooks`（例如 `Notification`、`Stop`、`SubagentStop`）指向旧端口 `4318`。当这些 Hook 触发并向不存在的端口发送 `curl` 请求时就会报错。
  - **解决：** 运行以下命令一键将 `hooks` 中的端口替换为新端口（以 `4319` 为例）：
    ```bash
    sed -i '' 's/http:\/\/localhost:4318\/notify/http:\/\/localhost:4319\/notify/g' ~/.claude/settings.json
    ```
    *(注：最新版本的 `make install` 已经自动包含了此修复逻辑)*。修改后请重启 Claude Code 会话。

### 3. 为什么 OTel 默认使用 4319 而不是标准的 4318 端口？
在部分 macOS 环境下，宿主机的 `4318` 端口可能被其他常驻进程（如 `lumo-daem`）静默占用，导致 Docker 无法正常绑定或数据被劫持。为了避免端口冲突，本系统默认将 OTel Collector 暴露在宿主机的 `4319` 端口，并将 Claude Code 的配置指向 `4319`。

### 3. 如何备份和迁移数据？
VictoriaMetrics 的数据存储在名为 `vm_data` 的 Docker Volume 中。如果你需要迁移数据：
```bash
# 导出数据
docker run --rm -v my-claude-observation_vm_data:/data -v $(pwd):/backup alpine tar czf /backup/vm_data_backup.tar.gz -C /data .
```
迁移至新机器后，使用相应的 `tar xzf` 命令将数据恢复至新的 volume 即可。
