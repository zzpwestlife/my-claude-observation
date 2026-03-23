**Langfuse + Claude Code 本地观测完整可操作步骤（macOS + Orbstack + Claude Code CLI）**

Claude Code 原生支持 **hooks 系统**（不是纯 OTEL），Langfuse 官方提供了专门的 **Claude Code 集成**（https://langfuse.com/integrations/other/claude-code）。它会在每次 Claude 回复后（Stop hook）捕获完整对话、工具调用（读写文件、bash、搜索等）、token/耗时，并生成结构化 traces。

**为什么不用纯 OTEL？**  
Claude Code 的 OTEL 主要发 **metrics + logs**（不是 traces），直接指向 Langfuse 的 `/api/public/otel` 会报 400 错误。Hooks 方式更可靠、功能更完整（会话分组、工具 spans），推荐优先使用。

整个流程 **5-15 分钟** 搞定，全本地自托管，零云费用，数据 100% 在你 Mac 上。

### 步骤 1：用 Orbstack 部署 Langfuse 自托管（本地 Docker）

Orbstack 已完美支持 `docker compose`，无需 Docker Desktop。

1. 克隆官方仓库（最新版）：
   ```bash
   git clone https://github.com/langfuse/langfuse.git
   cd langfuse
   ```

2. 启动（推荐 detached 模式）：
   ```bash
   docker compose up -d
   ```

   - 会自动拉起：Langfuse Web + Worker + Postgres + ClickHouse + Redis + MinIO。
   - 首次启动可能等 1-2 分钟（ClickHouse 初始化）。
   - 检查状态：`docker compose ps`（所有容器应为 Up）。

3. 访问 UI：
   - 打开浏览器 → http://localhost:3000
   - 首次注册（邮箱随意，本地无需验证）。
   - 进入后点击左上角 **Create Project** → 随便起名（例如 `claude-code-local`）。
   - 点击项目 → **Settings** → 复制：
     - **Public Key**（`pk-lf-...`）
     - **Secret Key**（`sk-lf-...`）

   **自托管专属**：`LANGFUSE_BASE_URL` 后面会用到 `http://localhost:3000`

**提示**：想重置就 `docker compose down -v` 再重启。资源占用约 1-2GB RAM，适合个人 Mac。

### 步骤 2：安装 Langfuse Python SDK（hook 需要）

```bash
python3 -m venv ~/langfuse-env
source ~/langfuse-env/bin/activate
pip install langfuse
```

（推荐用 pyenv/uv/conda 隔离环境，避免全局污染）

### 步骤 3：创建 Claude Code Hook（核心！）

1. 创建 hook 目录：
   ```bash
   mkdir -p ~/.claude/hooks
   ```

2. **复制 hook 脚本**（官方提供）：
   - 打开 https://langfuse.com/integrations/other/claude-code
   - 把页面里的 **langfuse_hook.py** 完整代码复制下来，保存为：
     ```bash
     nano ~/.claude/hooks/langfuse_hook.py
     ```
     （或用 VS Code 直接新建）

3. 赋予执行权限：
   ```bash
   chmod +x ~/.claude/hooks/langfuse_hook.py
   ```

### 步骤 4：全局注册 Stop Hook

编辑全局设置（Claude Code 会读取它）：
```bash
nano ~/.claude/settings.json
```

加入以下内容（如果文件已存在就合并）：

> python3 最好改为绝对路径的 python

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/langfuse_hook.py"
          }
        ]
      }
    ]
  }
}
```

### 步骤 5：每个项目开启 tracing（推荐 per-project）

在你要监控的项目根目录下新建：
```bash
nano .claude/settings.local.json
```

内容（替换你的 keys）：
```json
{
  "env": {
    "TRACE_TO_LANGFUSE": "true",
    "LANGFUSE_PUBLIC_KEY": "pk-lf-xxxxxxxxxxxx",
    "LANGFUSE_SECRET_KEY": "sk-lf-xxxxxxxxxxxx",
    "LANGFUSE_BASE_URL": "http://localhost:3000",
    "CC_LANGFUSE_DEBUG": "true"   // 调试时打开，生产可删
  }
}
```

### 步骤 6：测试 & 使用

1. 进入项目：
   ```bash
   cd /你的项目目录
   claude
   ```

2. 正常和 Claude Code 对话（发 prompt、让它改文件、跑命令等）。

3. 几秒后刷新 Langfuse UI（http://localhost:3000）：
   - 进入 **Traces** 页面
   - 你会看到：
     - 每个对话回合一个 Trace
     - LLM 生成 spans（含模型、token、耗时、成本）
     - 嵌套工具 spans（Read/Write/Bash/Tool 等）
     - Session 自动分组（同一个 `claude` 会话）

调试日志在 `~/.claude/state/langfuse_hook.log`

### 常见问题 & Tips（macOS + Orbstack 专属）

- **Hook 不触发** → 重启 Claude Code（`claude` 命令），或检查 `TRACE_TO_LANGFUSE=true`。
- **Self-hosted BASE_URL 报错** → 确认是 `http://localhost:3000`（不是 3001，Langfuse 自托管 API 和 UI 同端口）。
- **Orbstack 端口冲突** → Orbstack 默认暴露所有端口，无需额外设置。
- **想关掉 tracing** → 把 `settings.local.json` 里的 `TRACE_TO_LANGFUSE` 改成 `false`，或删文件。
- **多项目** → 每个项目放一个 `.claude/settings.local.json` 即可全局 hook 只在有这个文件的项目生效。
- **升级 Langfuse** → `cd langfuse && git pull && docker compose up -d --build`

**效果对比 Lumo**：  
Lumo 更轻量（纯本地 dashboard + 年度 Wrapped），适合只看成本/时长；Langfuse 功能远超（Prompt 版本管理、LLM-as-Judge 评估、Datasets、导出、团队协作、自定义 dashboard）。你现在两者都能用。

全部搞定后，**Claude Code 每次使用都会自动在 Langfuse 里留下完整可调试的 trace**，超级适合个人/小团队长期观测成本、质量、工具链路。

有任何一步卡住（比如 hook 脚本内容我没贴是因为官方会更新，建议直接复制页面），或想加成本计算/警报，随时贴错误截图我继续帮你调！现在就去跑 `docker compose up -d` 吧～

## 常见问题 QA

### Q1: 为什么 Langfuse 没有记录任何 trace？
**A:** 因为 langfuse Python SDK 未安装。Hook 脚本设计为 "fail-open"（导入失败直接退出），所以没有任何日志或错误提示。

### Q2: 为什么调试日志 `~/.claude/state/langfuse_hook.log` 不存在？
**A:** 因为 hook 脚本从未成功执行过，所以 `state` 目录虽然创建了，但日志文件未生成。

### Q3: 系统里已经有 Python，为什么还要创建虚拟环境？
**A:** 因为 Claude Code 使用的 Python 路径（`/Library/Developer/CommandLineTools/usr/bin/python3`）与系统默认路径不同，且该环境中未安装 langfuse。

### Q4: 如何验证 langfuse SDK 是否已正确安装？
**A:** 运行以下命令：
```bash
~/.claude/venv/bin/python3 -c "from langfuse import Langfuse; print('langfuse 模块验证成功')"
```

### Q5: 多项目如何区分？是否需要在 Langfuse 后台创建多个项目？
**A:** 是的，多项目区分通过 Key Pair 实现：
1. 在 Langfuse 后台为每个项目创建独立的项目
2. 每个项目获取独立的 `pk-lf-...` 和 `sk-lf-...`
3. 在各项目的 `.claude/settings.local.json` 中配置对应的 keys

### Q6: 如何关闭特定项目的 tracing？
**A:** 在该项目的 `.claude/settings.local.json` 中：
- 将 `TRACE_TO_LANGFUSE` 设为 `false`，或
- 直接删除该文件

### Q7: 如何查看详细的调试日志？
**A:** 日志文件位置：`~/.claude/state/langfuse_hook.log`
- 确保 `CC_LANGFUSE_DEBUG` 设为 `true` 以获得更详细的调试信息

### Q8: Langfuse 自托管的默认端口是多少？
**A:** `http://localhost:3000`（API 和 UI 同端口，不是 3001）

### Q9: 如何在虚拟环境中安装 langfuse？
**A:**
1. 创建虚拟环境：
   ```bash
   /usr/bin/python3 -m venv ~/.claude/venv
   ```
2. 安装 langfuse：
   ```bash
   ~/.claude/venv/bin/pip install langfuse
   ```
3. 更新 hook 配置中的 Python 路径为：
   ```
   ~/.claude/venv/bin/python3 ~/.claude/hooks/langfuse_hook.py
   ```