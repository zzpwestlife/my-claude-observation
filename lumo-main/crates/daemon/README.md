# Lumo Daemon - OTLP Receiver for Claude Code

独立的后台守护进程，接收 Claude Code 的 OTLP (OpenTelemetry Protocol) 遥测数据。

## 功能特性

- ✅ 接收 OTLP/HTTP JSON 格式的 trace 数据
- ✅ 标准 OTLP 端点：`http://localhost:4318/v1/traces`
- ✅ 健康检查端点：`http://localhost:4318/health`
- ✅ 自动启动（macOS launchd）
- ✅ 优雅关闭处理
- ✅ 结构化日志输出
- ✅ MVP 版本：打印接收到的数据到控制台

## 安装（macOS）

### 前置要求

- Rust 工具链
- macOS 系统

### 安装步骤

```bash
# 1. 进入项目根目录
cd /path/to/lumo

# 2. 运行安装脚本（会自动编译、安装、启动）
./scripts/install-daemon.sh
```

安装脚本会：
1. 编译 daemon（release 模式）
2. 复制二进制到 `/usr/local/bin/lumo-daemon`
3. 创建 launchd plist 配置
4. 启动服务并设置自动启动

### 验证安装

```bash
# 检查服务状态
launchctl list | grep com.lumo.daemon

# 测试健康检查
curl http://localhost:4318/health

# 应返回：
# {"status":"healthy","service":"lumo-daemon","version":"0.1.0"}
```

## 配置 Claude Code

配置 Claude Code 将 OTLP 数据发送到 daemon：

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

然后运行 Claude Code 命令，daemon 会接收并打印 trace 数据。

## 查看日志

```bash
# 实时查看标准输出日志
tail -f ~/Library/Logs/com.lumo.daemon/stdout.log

# 查看错误日志
tail -f ~/Library/Logs/com.lumo.daemon/stderr.log
```

## 管理服务

### 停止服务

```bash
launchctl unload ~/Library/LaunchAgents/com.lumo.daemon.plist
```

### 启动服务

```bash
launchctl load ~/Library/LaunchAgents/com.lumo.daemon.plist
```

### 重启服务

```bash
launchctl unload ~/Library/LaunchAgents/com.lumo.daemon.plist
launchctl load ~/Library/LaunchAgents/com.lumo.daemon.plist
```

### 完全卸载

```bash
./scripts/uninstall-daemon.sh
```

## 环境变量配置

daemon 支持以下环境变量（在 plist 文件中配置）：

- `LUMO_SERVER_ADDRESS`: 监听地址（默认：`127.0.0.1:4318`）
- `RUST_LOG`: 日志级别（默认：`lumo_daemon=info,tower_http=info`）

修改配置：

```bash
# 编辑 plist 文件
nano ~/Library/LaunchAgents/com.lumo.daemon.plist

# 重新加载
launchctl unload ~/Library/LaunchAgents/com.lumo.daemon.plist
launchctl load ~/Library/LaunchAgents/com.lumo.daemon.plist
```

## 测试 OTLP 端点

发送测试 trace 数据：

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "1544712660000000000",
          "endTimeUnixNano": "1544712661000000000",
          "attributes": [{
            "key": "test.attribute",
            "value": {"stringValue": "test value"}
          }]
        }]
      }]
    }]
  }'
```

检查日志应该能看到接收到的 span 信息。

## 架构说明

```
Claude Code → OTLP export → lumo-daemon:4318 → Parse → Print to console
                                                         (未来：存储到数据库)
```

### 模块结构

- `src/main.rs` - 入口点
- `src/server.rs` - Axum HTTP 服务器设置
- `src/handlers/` - HTTP 处理器
  - `health.rs` - 健康检查
  - `traces.rs` - OTLP trace 接收
- `src/otlp/parser.rs` - OTLP JSON 数据结构定义
- `src/config.rs` - 配置管理
- `src/shutdown.rs` - 优雅关闭处理

### 设计原则

- **模块化**：易于扩展新功能（如数据库存储）
- **标准化**：遵循 OTLP 规范
- **可观测性**：结构化日志，易于调试
- **可靠性**：优雅关闭，自动重启

## 路线图

### MVP (当前版本)
- [x] 接收 OTLP JSON 数据
- [x] 打印到控制台
- [x] macOS launchd 自动启动

### 未来版本
- [ ] SQLite 数据库存储
- [ ] 数据转换和分析
- [ ] Tauri 应用集成（查看器）
- [ ] Windows 支持（Windows Service）

## 故障排查

### 服务无法启动

```bash
# 检查日志
cat ~/Library/Logs/com.lumo.daemon/stderr.log

# 手动运行查看错误
/usr/local/bin/lumo-daemon
```

### 端口被占用

检查 4318 端口是否被其他进程占用：

```bash
lsof -i :4318
```

### 查看详细日志

修改 plist 中的 `RUST_LOG` 环境变量为 `debug` 或 `trace`。

## 许可证

同主项目
