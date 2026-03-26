# Claude Code 监控系统故障排查指南

本文档记录了 Claude Code 监控系统的常见问题排查流程和解决方案。

---

## 目录

1. [Grafana 无数据显示](#1-grafana-无数据显示)
2. [Stop Hook 错误](#2-stop-hook-错误)
3. [OTel Collector 导出失败](#3-otel-collector-导出失败)
4. [VictoriaMetrics 连接测试](#4-victoriametrics-连接测试)
5. [Grafana 认证问题](#5-grafana-认证问题)
6. [完整排查案例](#6-完整排查案例-2026-03-26)

---

## 1. Grafana 无数据显示

### 症状
Grafana 仪表盘正常加载，但所有面板显示 "No Data"。

### 可能原因及解决方案

#### 原因 A: Claude Code 会话未在配置修改后重启
Claude Code **不会热加载** `settings.json` 配置。如果修改了遥测配置，必须重启会话。

**解决方案:**
1. 在 Claude Code 终端中输入 `/exit` 或按 `Ctrl+C`
2. 重新启动 Claude Code
3. 等待约 15-30 秒让数据流入 VictoriaMetrics
4. 刷新 Grafana 页面

#### 原因 B: 缺少累积模式配置
VictoriaMetrics 需要 `cumulative` 模式来处理 OTel 指标。

**解决方案:** 检查 `~/.claude/settings.json` 包含:
```json
{
  "env": {
    "OTEL_METRICS_EXPORTER_TEMPORALITY_PREFERENCE": "cumulative"
  }
}
```

---

## 2. Stop Hook 错误

### 症状
终端出现错误：`Stop hook error: Failed with non-blocking status code`

### 原因
OTel 端口被修改（如从 4318 改为 4319），但 `settings.json` 中的 `hooks` 仍引用旧端口。

### 解决方案
```bash
# 修复 hooks 使用新端口 (4319)
sed -i '' 's/4318\/notify/4319\/notify/g' ~/.claude/settings.json
```

然后重启 Claude Code 会话。

---

## 3. OTel Collector 导出失败

### 症状
OTel Collector 日志显示：
```
Exporting failed. Dropping data.
error: "Permanent error: Permanent error: context deadline exceeded"
```

或代理相关错误：
```
error: "Permanent error: Post \"http://victoriametrics:8428/api/v1/write\": proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused"
```

### 排查步骤

#### 步骤 1: 检查 OTel Collector 日志
```bash
docker-compose logs otel-collector --tail 100 | grep -E "error|failed|export"
```

#### 步骤 2: 检查 VictoriaMetrics 是否正常运行
```bash
curl -s http://localhost:8428/health
```
预期：返回空响应（200 OK）

#### 步骤 3: 检查容器网络
```bash
docker network inspect my-claude-observation_monitoring
```
所有容器应在同一网络中。

### 解决方案

#### 方案 A: 添加 NO_PROXY 环境变量（已解决代理问题）
系统 HTTP_PROXY 设置导致 OTel Collector **和 Grafana** 尝试通过代理连接内部服务。

**修复方法:** 在 `docker-compose.yml` 中为 `otel-collector` **和** `grafana` 添加:
```yaml
services:
  otel-collector:
    environment:
      - NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
      - no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics

  grafana:
    environment:
      - NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
      - no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
```

然后重启：
```bash
docker-compose up -d
```

**症状:** 数据源健康检查显示 `proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused`

#### 方案 B: 增加超时时间
如果网络延迟较高，增加导出超时：

**修改 `otel-collector-config.yaml`:**
```yaml
exporters:
  prometheusremotewrite:
    endpoint: "http://victoriametrics:8428/api/v1/write"
    timeout: 60s
    retry_on_failure:
      enabled: false
```

---

## 4. VictoriaMetrics 连接测试

### 验证数据流

```bash
# 检查 VictoriaMetrics 中的指标
curl -s 'http://localhost:8428/api/v1/label/__name__/values' | grep claude_code

# 预期输出:
# "claude_code_active_time_seconds_total"
# "claude_code_cost_usage_USD_total"
# "claude_code_token_usage_tokens_total"
# "claude_code_lines_of_code_count_total"
# "claude_code_session_count_total"
# "claude_code_code_edit_tool_decision_total"
```

### 查询具体指标值
```bash
curl -s 'http://localhost:8428/api/v1/query?query=claude_code_cost_usage_USD_total' | jq '.'
```

---

## 5. Grafana 认证问题

### 症状
访问 Grafana 时显示 `Invalid username or password`

### 原因
持久化卷保留了旧的凭据。

### 解决方案
重置 Grafana 数据：
```bash
docker-compose down -v grafana_data
docker-compose up -d
```

**注意:** 这将重置所有 Grafana 设置，但仪表盘配置会从 `grafana/provisioning/` 自动恢复。

---

## 6. 完整排查案例 (2026-03-26)

### 案例 A: OTel Collector 导出失败

#### 问题描述
项目启动后，Grafana 仪表盘无法显示 Claude Code 监控数据。

#### 排查过程

##### 1. 初步检查
```bash
# 检查容器状态
docker-compose ps

# 输出显示所有容器正常运行
NAME              STATUS
grafana           Up (unhealthy)
otel-collector    Up
victoriametrics   Up (unhealthy)
```

##### 2. 检查 VictoriaMetrics 是否收到数据
```bash
curl -s 'http://localhost:8428/api/v1/label/__name__/values' | jq '.data[]'
```

**结果:** 只有基础 Go 指标，没有 Claude Code 指标。

##### 3. 检查 OTel Collector 日志
```bash
docker-compose logs otel-collector --tail 100 | grep -i "error\|failed"
```

**发现关键错误:**
```
Exporting failed. Dropping data.
error: "Permanent error: Permanent error: context deadline exceeded"
```

继续查看详细错误：
```
error: "Permanent error: Post \"http://192.168.107.2:8428/api/v1/write\":
       proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused"
```

##### 4. 问题分析
错误信息显示 OTel Collector 尝试通过 `127.0.0.1:7897`（系统代理）连接 VictoriaMetrics，但该地址在容器内无法访问。

**根本原因:** 系统设置了 `HTTP_PROXY` 环境变量，OTel Collector 继承该设置并尝试通过代理连接内部服务。

##### 5. 解决方案实施

**修改 `docker-compose.yml`，添加 NO_PROXY 环境变量:**
```yaml
services:
  otel-collector:
    environment:
      - NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
      - no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
```

**同时调整 `otel-collector-config.yaml`:**
```yaml
exporters:
  prometheusremotewrite:
    endpoint: "http://192.168.107.2:8428/api/v1/write"
    timeout: 60s
    retry_on_failure:
      enabled: false
```

##### 6. 验证修复
```bash
docker-compose up -d otel-collector
sleep 25
docker-compose logs otel-collector --tail 50 | grep -E "error|failed"
```

**结果:** 无错误日志。

##### 7. 确认数据流入
```bash
curl -s 'http://localhost:8428/api/v1/label/__name__/values' | grep claude_code

# 输出:
# "claude_code_active_time_seconds_total"
# "claude_code_cost_usage_USD_total"
# "claude_code_token_usage_tokens_total"
# ...
```

---

### 案例 B: Grafana 数据源无法连接 VictoriaMetrics (2026-03-26 续)

#### 问题描述
OTel Collector 修复后，VictoriaMetrics 已收到数据，但 Grafana 仪表盘仍显示 "No Data"。

#### 症状
- VictoriaMetrics 直接查询正常：
  ```bash
  curl -s 'http://localhost:8428/api/v1/query?query=claude_code_cost_usage_USD_total'
  # 返回正常数据
  ```

- Grafana 数据源健康检查失败：
  ```bash
  curl -s 'http://admin:admin@localhost:3001/api/datasources/1/health'
  # 返回: "proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused"
  ```

- Grafana 日志显示大量 400 错误：
  ```
  logger=context msg="Request Completed" method=POST path=/api/ds/query status=400
  ```

#### 排查步骤

##### 步骤 1: 验证 VictoriaMetrics 数据
```bash
curl -s 'http://localhost:8428/api/v1/query?query=claude_code_cost_usage_USD_total' | jq '.'
```

**预期:** 返回包含 `value` 和 `timestamp` 的 JSON。

##### 步骤 2: 测试 Grafana 数据源代理
```bash
curl -s 'http://admin:admin@localhost:3001/api/datasources/1/health'
```

**问题表现:**
```json
{
  "message": "Post \"http://192.168.107.2:8428/api/v1/query\":
              proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused",
  "status": "ERROR"
}
```

##### 步骤 3: 检查 Grafana 容器网络
```bash
docker network inspect my-claude-observation_monitoring | jq '.[0].Containers'
```

**确认:** Grafana 和 VictoriaMetrics 在同一网络中。

##### 步骤 4: 确定根本原因
Grafana 容器同样继承了宿主机的 `HTTP_PROXY` 环境变量，尝试通过代理 (`127.0.0.1:7897`) 连接 VictoriaMetrics。

#### 解决方案

##### 1. 为 Grafana 添加 NO_PROXY 环境变量

**修改 `docker-compose.yml`:**
```yaml
grafana:
  environment:
    - NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
    - no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,victoriametrics
```

##### 2. 修改数据源配置使用 IP 地址

**修改 `grafana/provisioning/datasources/victoriametrics.yaml`:**
```yaml
datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://192.168.107.2:8428  # 使用容器 IP 替代主机名
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
```

##### 3. 重启 Grafana
```bash
docker-compose up -d grafana
sleep 5
```

#### 验证修复

##### 1. 检查数据源健康状态
```bash
curl -s 'http://admin:admin@localhost:3001/api/datasources/1/health'
```

**预期输出:**
```json
{
  "status": "OK",
  "message": "Successfully queried the Prometheus API."
}
```

##### 2. 通过 Grafana 代理查询
```bash
curl -s 'http://admin:admin@localhost:3001/api/datasources/proxy/1/api/v1/query?query=claude_code_cost_usage_USD_total' | jq '.'
```

**预期:** 返回包含数据的 JSON。

##### 3. 检查仪表盘
```bash
curl -s 'http://admin:admin@localhost:3001/api/search?type=dash-db' | jq '.[].title'
```

**预期:** `"Claude Code Metrics"`

##### 4. 访问 Grafana UI
- URL: `http://localhost:3001`
- 路径：Dashboards → Applications → Claude Code Metrics
- 面板应显示数据（37 个面板）

---

### 排查流程图

```
Grafana 显示 "No Data"
        │
        ▼
┌───────────────────────┐
│ 1. 检查 VM 是否有数据   │
│ curl localhost:8428   │
└───────────┬───────────┘
            │
    ┌───────┴───────┐
    │               │
   有数据          无数据
    │               │
    ▼               ▼
┌───────────────┐ ┌───────────────────┐
│ 2. 检查 Grafana│ │ 检查 OTel Collector│
│    数据源健康  │ │    日志和导出状态  │
└───────┬───────┘ └───────────────────┘
        │
  ┌─────┴─────┐
  │           │
 OK         ERROR
  │           │
  │           ▼
  │    ┌──────────────────┐
  │    │ 检查是否代理问题  │
  │    │ proxyconnect ... │
  │    └────────┬─────────┘
  │             │
  │             ▼
  │    ┌──────────────────┐
  │    │ 添加 NO_PROXY    │
  │    │ 到 docker-compose│
  │    └──────────────────┘
  │
  ▼
┌─────────────────┐
│ 3. 验证仪表盘   │
│ 刷新页面查看数据 │
└─────────────────┘
```

---

## 7. 快速诊断检查清单

---

## 7. 快速诊断检查清单

按顺序执行以下检查：

- [ ] **步骤 1:** `docker-compose ps` - 所有容器是否运行？
- [ ] **步骤 2:** `curl localhost:8428/api/v1/label/__name__/values | grep claude_code` - VM 有数据吗？
- [ ] **步骤 3:** `curl admin:admin@localhost:3001/api/datasources/1/health` - 数据源健康？
- [ ] **步骤 4:** 刷新 Grafana 页面 - 仪表盘显示数据？

如果任何一步失败，参考上述对应章节进行排查。

---

## 附录：常用调试命令速查

```bash
# 容器状态
docker-compose ps

# 查看日志
docker-compose logs -f otel-collector
docker-compose logs otel-collector --tail 100

# 重启服务
docker-compose restart otel-collector
docker-compose down && docker-compose up -d

# VictoriaMetrics 健康检查
curl -s http://localhost:8428/health

# 查询指标
curl -s 'http://localhost:8428/api/v1/query?query=<metric_name>'

# 列出所有指标
curl -s 'http://localhost:8428/api/v1/label/__name__/values'

# Grafana 仪表盘列表
curl -s 'http://admin:admin@localhost:3001/api/search?type=dash-db'
```

---

## 架构图

```
┌─────────────┐
│ Claude Code │ (macOS 终端)
│  (v2.1.84)  │
└──────┬──────┘
       │ HTTP/JSON OTLP
       │ localhost:4319
       ▼
┌──────────────────┐
│ OTel Collector   │ (Docker)
│  (port 4318→4319)│
└────────┬─────────┘
         │ Prometheus Remote Write
         │ (需 NO_PROXY 配置)
         ▼
┌────────────────────┐
│ VictoriaMetrics    │ (Docker)
│  (port 8428)       │
│  保留期：12 个月     │
└────────┬───────────┘
         │ PromQL
         ▼
┌────────────────────┐
│ Grafana            │ (Docker)
│  (port 3001)       │
│  admin/admin       │
└────────────────────┘
```

---

## 关键配置清单

| 组件 | 配置文件 | 关键设置 |
|------|----------|----------|
| Claude Code | `~/.claude/settings.json` | `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_METRICS_EXPORTER_TEMPORALITY_PREFERENCE` |
| OTel Collector | `otel-collector-config.yaml` | `endpoint`, `timeout`, `NO_PROXY` |
| Docker | `docker-compose.yml` | 网络配置，环境变量 |
| Grafana | `grafana/provisioning/` | Datasource, Dashboards |

---

## 版本信息

| 组件 | 版本 |
|------|------|
| Claude Code | 2.1.84 |
| OTel Collector | 0.148.0 |
| VictoriaMetrics | v1.138.0 |
| Grafana | 11.5.0 |
| 文档最后更新 | 2026-03-26 |

---

## 修订历史

| 日期 | 变更内容 |
|------|----------|
| 2026-03-26 | 新增案例 B：Grafana 数据源代理问题排查 |
| 2026-03-26 | 新增快速诊断检查清单和排查流程图 |
| 2026-03-26 | 更新方案 A，补充 Grafana NO_PROXY 配置 |
