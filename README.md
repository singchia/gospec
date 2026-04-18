# gospec — Go 项目 SDLC 全流程规范 Skill

**中文** | [English](README.en.md)

> **给 AI Agent 用的、覆盖 SDLC 左移到右移的 Go 项目规范集。**

---

## 这是什么

`gospec` 是一个面向 Go 后端项目的 AI Agent Skill，用中文写成。它告诉 Agent：

- 拿到一个需求，**选什么载体**（Issue / RFC / PRD / Epic）
- 编码前**先做什么设计**（分层 / monorepo / ADR / HLD）
- 写 API / 数据模型 / 代码 / 测试 时**哪些是红线**
- 提 PR 前**自查哪些项**
- 上线前**做哪些可观测性 / 安全 / 运维准备**
- 上线后**怎么复盘 / 怎么应对事故**

它不是一份规范文档，而是一个**可被 AI Agent 按需加载的知识库**：Agent 拿到任务后先读路由表，只加载当前任务相关的 1-3 个子文件，不会一次性吞掉整个规范。

## 技术栈基线（参考，可替换）

规范只约束分层、依赖方向、错误处理、测试、安全等通用项，**不锁框架**。下表只是参考选型。

| 领域 | 参考选型 | 常见替换 |
|------|---------|---------|
| 语言 | Go 1.21+ | — |
| Web 框架 | Kratos v2 | gin / CloudWeGo Hertz / chi / echo / 原生 net/http |
| API 协议 | Protobuf v3 + gRPC + HTTP/REST | OpenAPI + REST |
| ORM | gorm.io/gorm | sqlx / ent / sqlc |
| 存储 | MySQL / Redis / ClickHouse / InfluxDB | 按业务需要选择 |
| 日志 | `log/slog`（推荐） | zap |
| 指标 | Prometheus client_golang | OpenTelemetry metrics |
| 追踪 | OpenTelemetry | — |
| 认证 | JWT（golang-jwt/jwt v5） | Auth0 / Keycloak / Casdoor / 自研 |
| 测试 | testing + testify + testcontainers-go | — |
| CI/CD | GitHub Actions + golangci-lint + govulncheck + trivy + cosign | GitLab CI / Drone / Buildkite |

详细选型和约束见 `spec/05-coding/README.md`。

---

## 目录结构

```
gospec/
├── spec/                  # 规范正文（按 SDLC 阶段组织）
│   ├── spec.md            # 入口：任务路由表 + 核心约束
│   ├── 01-requirement/    # 需求（issue/rfc/prd/epic/lifecycle）
│   ├── 02-architecture/   # 架构（layering/monorepo/ADR/HLD）
│   ├── 03-api/            # API（proto/http/middleware/versioning）
│   ├── 04-data-model/     # 数据模型（mysql/redis/clickhouse/influxdb）
│   ├── 05-coding/         # 编码（naming/errors/concurrency/patterns/style）
│   ├── 06-testing/        # 测试（unit/integration/fuzz-bench）
│   ├── 07-code-review.md  # PR 自查清单
│   ├── 08-delivery/       # 交付（git/cicd/release）
│   ├── 09-documentation.md
│   ├── 10-observability/  # 日志 / 指标 / 追踪 / SLO
│   ├── 11-security/       # 认证 / 输入 / 密钥 / 隐私 / 威胁建模
│   ├── 12-operations/     # 部署 / 事故 / 容量 / 备份
│   └── 13-database-migration/  # migration / 在线 DDL / 数据治理
│
├── docs/
│   └── templates/         # 可复制的文档模板（单一真相源）
│       ├── product-requirement-template.md       (PRD)
│       ├── technical-rfc-template.md             (RFC)
│       ├── architecture-decision-record-template.md  (ADR)
│       ├── high-level-design-template.md         (HLD)
│       ├── pull-request-template.md              (PR)
│       └── project-agents-template.md            (用户项目根 AGENTS.md)
│
├── scripts/
│   ├── install.sh         # 用户安装脚本（一行命令安装 + 创建 AGENTS.md）
│   ├── build-skill.py     # 维护者用：构建 .skill 打包产物（跨平台，CI 使用）
│   ├── build-skill.sh     # 维护者用：build-skill.py 的 bash 等价版本
│   └── validate-skill.py  # 自包含 frontmatter + 必备文件校验
│
├── .github/
│   └── workflows/
│       ├── validate.yml   # push / PR 触发：校验 + smoke test
│       └── release.yml    # tag push 触发：构建并发布 .skill 到 GitHub Release
│
├── SKILL.md               # Skill 元信息（Claude Code 加载入口）
├── AGENTS.md              # Agent 行为约束入口
├── CHANGELOG.md           # 版本历史
├── LICENSE                # MIT
└── README.md              # 本文件
```

---

## 核心特性

### 1. 渐进式披露

Agent 不会一次性读完所有规范。`spec/spec.md` 里有一张"任务 → 必读文件"路由表：

```
写一个新 HTTP handler
→ 03-api/proto.md + 03-api/http.md + 05-coding/errors.md
→ 按需再加载 11-security/auth.md、10-observability/logging.md

写一个 MySQL migration
→ 13-database-migration/migration.md
→ 如果是大表再加载 online-ddl.md

部署 / 回滚
→ 12-operations/deployment.md
```

典型任务只加载 2-5 个子文件，每个 80-300 行，避免上下文爆炸。

### 2. 多存储覆盖

数据层不只是 MySQL。`04-data-model/` 为 4 种主流存储分别写了设计约束：

- **MySQL**（GORM / DAO / 事务 / 索引 / 深翻页）
- **Redis**（key 命名 / TTL / 大 key / 分布式锁 / 缓存三大问题）
- **ClickHouse**（MergeTree / LowCardinality / 批量写入 / 物化视图）
- **InfluxDB**（tag/field / 基数控制 / retention / downsampling）

### 3. 单服务 + Monorepo 双层架构

`02-architecture/` 既讲单服务内部的严格分层（Kratos 风格：`cmd → server → service → biz → data → model`，框架中性），也讲 monorepo 仓库结构：**`cmd/` 按 service 切、`internal/` 按 Bounded Context 切**，配合 module 策略（单 `go.mod` vs `go.work`）、BC 边界（linter 强制）、CODEOWNERS、CI affected detection。

### 4. 设计模式库

`05-coding/patterns.md` 覆盖 10 个 Go 项目真的用得上的模式：

Functional Options / Constructor Injection / Strategy / Decorator / Adapter / Worker Pool / Pipeline / Errgroup / Retry + Backoff / Outbox

每个模式都注明"何时不要用"和常见反模式，避免套用。

### 5. SDLC 右移完整覆盖

不只讲编码前的设计，也讲上线后的运维：

- `10-observability/` — 日志 / 指标 / 追踪 / SLO / 告警
- `11-security/` — 威胁建模 / 认证 / 输入防护 / 密钥管理 / 供应链 / 容器安全 / 隐私合规
- `12-operations/` — 部署策略 / 回滚 / feature flag / on-call / 事故响应 / Postmortem / 容量 / 混沌 / 备份灾难恢复
- `13-database-migration/` — migration 工具 / 在线 DDL / backfill / 数据保留

### 6. 需求载体分级

`01-requirement/` 明确区分 4 种需求载体，每种有独立流程：

- **Issue** — bug / 小改 / 配置调整，存 issue tracker
- **RFC** — 纯技术变更（重构 / 依赖升级 / 性能优化）
- **PRD** — 用户可感知的功能
- **Epic** — 跨季度战略，拆成多个 PRD

配有升级规则（issue 里的长讨论如何沉淀到 ADR / RFC / Postmortem）、状态门禁、变更追溯、上线复盘等共通流程。

---

## 如何使用

gospec 兼容 [skills.sh](https://skills.sh) 的 Open Agent Skills 协议，任何 [skills.sh 支持的 agent](https://skills.sh)（45+ 种，包括 Claude Code / Cursor / Cline / Codex / Gemini CLI / GitHub Copilot 等）都可以通过 `npx skills add` 安装。

### 方式一：`npx skills add`（标准入口，最简单）

在你的 Go 项目根目录运行：

```bash
cd your-go-project
npx skills add singchia/gospec        # 项目级安装到 .claude/skills/gospec/
# 或全局安装：
npx skills add singchia/gospec -g     # 安装到 ~/.claude/skills/gospec/
```

之后 Claude Code 等支持 SKILL.md 的 agent 会在你写 / 审查 / 重构 Go 代码时自动激活 gospec，并在首次激活时主动询问是否在项目根创建 `AGENTS.md`。

### 方式二：`install.sh`（一行命令，自动落 AGENTS.md + Cursor 规则）

如果你想立刻把规则落到项目根（不等 agent 提示），或者你的 agent 不读 SKILL.md 必须靠 AGENTS.md / Cursor rules 触发：

```bash
cd your-go-project
bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/install.sh)
```

这一行会做三件事：

1. **安装 gospec skill** 到 `~/.claude/skills/gospec/`（如果还没装）
2. **在项目根创建 `AGENTS.md`**（Codex / Cline / 通用 agent 入口）
3. **在项目根创建 `.cursor/rules/gospec.mdc`**（Cursor 单文件规则，自带 `globs`，编辑 `.go` / `.proto` / `Dockerfile` / migration 时自动附加，**避免 Cursor 每次让用户手动选择**）

跳过 Cursor 落盘：`NO_CURSOR=1 bash <(curl ...)`

之后任何 agent（Claude Code / Cursor / Cline / Codex / Gemini CLI / GitHub Copilot）打开你的项目，都会自动加载 gospec 的任务路由表 + 核心约束。

> **AGENTS.md vs SKILL.md 的区别**：
> - `SKILL.md` 是 Claude Code 通过 [skills.sh](https://skills.sh) 协议自动加载的入口，作用域是整个 skill
> - `AGENTS.md` 是 [agentsmd.net](https://agentsmd.net) 开放约定，放在项目根，告诉**所有** agent"本项目用了 gospec"
> - 两者互补：SKILL.md 解决"agent 怎么加载 skill 内容"，AGENTS.md 解决"agent 怎么知道当前项目用了哪些 skill"

### 方式三：项目级 install.sh（不影响其他项目）

```bash
cd your-go-project
SKILL_DIR=.claude/skills/gospec bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/install.sh)
```

### 方式四：手动安装

```bash
# 1. clone skill
git clone https://github.com/singchia/gospec ~/.claude/skills/gospec

# 2. 在你的项目根复制 AGENTS.md
cd your-go-project
cp ~/.claude/skills/gospec/docs/templates/project-agents-template.md ./AGENTS.md

# 3. 提交
git add AGENTS.md && git commit -m "chore: add gospec AGENTS.md"
```

### 方式五：离线 / 内网分发（.skill 包）

GitHub Releases 提供打包好的 `gospec.skill`（zip 格式，约 130KB / 68 文件）：

```bash
curl -L -o gospec.skill https://github.com/singchia/gospec/releases/latest/download/gospec.skill
unzip gospec.skill -d ~/.claude/skills/
cp ~/.claude/skills/gospec/docs/templates/project-agents-template.md ./AGENTS.md
```

或者自己构建：

```bash
git clone https://github.com/singchia/gospec && cd gospec

# 跨平台（推荐，Windows / macOS / Linux 通用，仅需 python3 + pyyaml）
python3 scripts/build-skill.py         # 输出到 ./dist/gospec.skill

# 或 bash 版本（macOS / Linux，需 bash + zip）
scripts/build-skill.sh
```

### 手动使用（人类阅读）

即使没有 Agent，这份规范也可以作为团队的 SDLC 手册直接读——每个子目录都有 `README.md` 作为二级路由，每个子文件都有"适用场景"和"自查清单"。

### 验证安装

安装成功后，让 Claude 或其他 agent 跑一句：

> 我有一个新需求：把项目从 klog 迁到 log/slog。请按 gospec 的流程推进。

Agent 应该：
1. 自动读到 `AGENTS.md` 或激活 gospec skill
2. 读 `spec/spec.md` 的任务路由表
3. 判断这是技术变更，应该走 RFC（不是 PRD / issue）
4. 读 `spec/01-requirement/technical-rfc.md` 和 `docs/templates/technical-rfc-template.md`
5. 提议为你创建 `docs/rfc/RFC-001-migrate-to-slog.md`

如果 agent 没按这个流程走，检查：
- `AGENTS.md` 是否存在于项目根
- `~/.claude/skills/gospec/SKILL.md` 是否存在

---

## 规范原则

1. **渐进式披露**：SKILL.md → spec.md（路由表）→ 子文件（按需加载）
2. **单一真相源**：规则在 `spec/`，模板在 `docs/templates/`，不重复
3. **相互引用而非复制**：跨主题的内容（如 trace_id 上下文传播）在一处定义，其他位置 link 过来
4. **强制约束作为护栏**：`spec/spec.md` 顶部有"核心约束"，Agent 全程记着，即使没读对应子文件
5. **每个子文件有自查清单**：Agent 完成任务后可就地核对
6. **模板与规则分离**：`docs/templates/` 是可复制的骨架，`spec/` 是规则和必填字段表

---

## 贡献

欢迎 PR 和 Issue。本项目自身遵循它描述的规范——提交时请参照 `spec/08-delivery/git.md`。

## 许可证

[MIT](LICENSE)
