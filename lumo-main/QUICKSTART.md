# Lumo OTLP Daemon - 快速启动指南

## 5 分钟快速开始

### 1. 安装 Daemon

```bash
# 在项目根目录执行
./scripts/install-daemon.sh
```

这会自动：
- ✅ 编译 daemon
- ✅ 安装到 `/usr/local/bin/lumo-daemon`
- ✅ 配置 launchd 自动启动
- ✅ 启动服务

### 2. 验证运行

```bash
# 检查健康状态
curl http://localhost:4318/health

# 应返回：
# {"status":"healthy","service":"lumo-daemon","version":"0.1.0"}
```

### 3. 配置 Claude Code

```bash
# 设置环境变量
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

# 然后正常使用 Claude Code
claude code
```

### 4. 查看接收到的数据

```bash
# 实时查看日志
tail -f ~/Library/Logs/com.lumo.daemon/stdout.log
```

当你使用 Claude Code 执行命令时，会看到类似这样的输出：

```
2026-01-25T12:00:00.000Z INFO lumo_daemon: Received OTLP trace export request
2026-01-25T12:00:00.000Z INFO lumo_daemon: Service: claude-code
2026-01-25T12:00:00.000Z INFO lumo_daemon:   Scope: claude-code-instrumentation
2026-01-25T12:00:00.000Z INFO lumo_daemon:     Span[5B8EFFF7]: name='tool.Read', kind=Internal, duration=125000ns, attributes=[tool.name=Read, file.path=/path/to/file]
2026-01-25T12:00:00.000Z INFO lumo_daemon: Processed 1 spans successfully
```

## 常用命令

### 服务管理

```bash
# 查看状态
launchctl list | grep com.lumo.daemon

# 停止服务
launchctl unload ~/Library/LaunchAgents/com.lumo.daemon.plist

# 启动服务
launchctl load ~/Library/LaunchAgents/com.lumo.daemon.plist

# 卸载
./scripts/uninstall-daemon.sh
```

### 日志查看

```bash
# 标准输出（主要日志）
tail -f ~/Library/Logs/com.lumo.daemon/stdout.log

# 错误日志
tail -f ~/Library/Logs/com.lumo.daemon/stderr.log
```

### 测试端点

```bash
# 健康检查
curl http://localhost:4318/health

# 发送测试 trace
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"scopeSpans":[{"spans":[{"traceId":"TEST123","spanId":"SPAN456","name":"test","kind":1,"startTimeUnixNano":"1000000000"}]}]}]}'
```

## 故障排查

### 问题：端口已被占用

```bash
# 查看谁在使用 4318 端口
lsof -i :4318

# 如需更换端口，编辑 plist
nano ~/Library/LaunchAgents/com.lumo.daemon.plist
# 修改 LUMO_SERVER_ADDRESS 环境变量
# 然后重新加载服务
```

### 问题：服务无法启动

```bash
# 查看错误日志
cat ~/Library/Logs/com.lumo.daemon/stderr.log

# 手动运行 daemon 查看详细错误
/usr/local/bin/lumo-daemon
```

### 问题：收不到 Claude Code 数据

1. 确认环境变量已设置：
```bash
echo $OTEL_EXPORTER_OTLP_ENDPOINT
# 应输出：http://localhost:4318
```

2. 确认 daemon 正在运行：
```bash
curl http://localhost:4318/health
```

3. 查看 daemon 日志是否有请求进来

## 下一步

- 📖 查看 [daemon/README.md](daemon/README.md) 了解详细文档
- 🔍 探索接收到的 trace 数据结构
- 🚀 等待后续版本支持数据库存储和可视化

## 当前限制（MVP 版本）

- ✅ 接收并打印 OTLP 数据
- ❌ 暂不支持数据持久化
- ❌ 暂无 UI 查看器
- ❌ 仅支持 macOS

后续版本会逐步添加这些功能。
