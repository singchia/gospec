# gospec — Go 项目 SDLC 全流程规范 Skill

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

## 技术栈基线

| 领域 | 选型 |
|------|------|
| 语言 | Go 1.21+ |
| Web 框架 | go-kratos/kratos v2 |
| API 协议 | Protocol Buffers v3 + gRPC + HTTP/REST |
| ORM | gorm.io/gorm |
| 存储 | MySQL / Redis / ClickHouse / InfluxDB |
| 日志 | `log/slog`（推荐）/ zap |
| 指标 | Prometheus client_golang |
| 追踪 | OpenTelemetry |
| 认证 | Casdoor + JWT |
| 测试 | testing + testify + testcontainers-go |
| CI/CD | GitHub Actions + golangci-lint + govulncheck + trivy + cosign |

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
│   └── templates/         # 可复制的文档模板
│       ├── product-requirement-template.md       (PRD)
│       ├── technical-rfc-template.md             (RFC)
│       ├── architecture-decision-record-template.md  (ADR)
│       ├── high-level-design-template.md         (HLD)
│       └── pull-request-template.md
│
├── SKILL.md               # Skill 元信息（给 Agent 发现用）
├── AGENTS.md              # Agent 行为约束入口
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

`02-architecture/` 既讲单服务内部的严格分层（`cmd → web → controlplane → repo → model`），也讲 monorepo 仓库结构（`cmd/ internal/ pkg/ api/`）、module 策略（单 go.mod vs go.work）、domain 边界、CODEOWNERS、CI affected detection。

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

### Claude Code

把这个仓库 clone 到本地，在你的 Go 项目里引用它，或者直接把 `SKILL.md` 和 `spec/` 放到你项目的 `.claude/skills/` 目录。

Agent 会在看到 Go 项目时自动激活此 Skill，并按 `spec/spec.md` 的路由表按需加载规范。

### Cursor / Cline / Windsurf

复制 `spec/` 目录内容到对应的 rules / instructions 路径。建议把 `spec/spec.md` 设为必读入口。

### 手动使用

即使没有 Agent，这份规范也可以作为团队的 SDLC 手册直接读——每个子目录都有 `README.md` 作为二级路由，每个子文件都有"适用场景"和"自查清单"。

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
