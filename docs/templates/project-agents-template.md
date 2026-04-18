# AGENTS.md

> 本项目遵循 [gospec](https://github.com/singchia/gospec) — Go 后端项目 SDLC 全流程规范。
>
> 本文件由 `scripts/install.sh` 自动生成。完整规范见 gospec 仓库。

## Agent 必读

任何编码 / 设计 / API / 数据 / 测试 / CI / 部署 / 监控 / 安全 / 文档 任务，**先按 gospec 规范走**。

### 第一步：找到 gospec 任务路由表

按以下顺序查找 spec 入口：

1. `~/.claude/skills/gospec/spec/spec.md`（个人安装，推荐）
2. `.claude/skills/gospec/spec/spec.md`（项目级安装）
3. 上面都不存在 → 重新安装：
   ```bash
   git clone https://github.com/singchia/gospec ~/.claude/skills/gospec
   ```

### 第二步：路由 → 加载

读 `spec/spec.md` 顶部的"任务路由表"，找到当前任务对应的 1-3 个子文件，**只读必要文件**，不要顺序读完整个 spec。

### 第三步：实施 + 自查

按子文件指引实施，结束前对照文件末尾的"自查清单"逐项核对。

### 第四步：PR 前对照 review 清单

提交 PR 前对照 `spec/07-code-review.md` 自查清单。

---

## 核心约束（无需读 spec 也要遵守）

> 这些是任何任务都要守的红线。不论 agent 是否加载了完整 spec，都不能违反。

### 架构
- **单服务**：`cmd → server → service → biz → data → model`，禁止跨层调用（`service` 不能直连 `data`）
- **monorepo**：`cmd/` 按 service 切、`internal/` 按 **Bounded Context** 切；跨 BC 禁止直接 import，必须通过 API / 事件 / `internal/pkg/`
- 接口在消费方定义，禁止循环依赖
- `internal/pkg/`、`model/` 不依赖任何业务层
- 依赖通过构造函数注入，不使用全局变量
- 每个目录都被 CODEOWNERS 覆盖

### 编码
- 禁止 `_ = fn()` 忽略错误（确实想丢弃必须注释说明）
- 共享状态必须加锁，测试必须带 `-race`
- 错误用 `%w` 包装；不重复记录（要么处理要么传播）
- 所有涉及 IO 的函数第一个参数为 `context.Context`
- `init()` 仅允许做注册（pprof / metrics collector / driver），禁止做 IO 或可能 panic
- 禁止全局可变变量（只读单例 / collector 除外）
- 避免 `any` / `interface{}` 出现在公共 API 边界（解码 / SDK 适配等不可避免时就近注释）

### API
- 所有 API 变更先更新 `.proto`，禁止改生成代码
- Handler 必须有 Swagger 注释：`@Summary`、`@Router`、`@Success` 缺一不可
- 响应格式统一：`{code, message, data}`
- 破坏性变更走新版本，原版本只允许加非破坏性内容

### 测试
- 新功能必须有单元测试
- CI 强制启用 `-race`
- E2E 测试必须清理数据

### Git
- 提交格式：`<type>(<scope>): <desc>`（Conventional Commits）
- 禁止提交敏感信息（密码、密钥、token）
- 禁止 force push main/master

### 构建 / 交付
- **所有构建 / 产物 / 部署目标必须由根 Makefile 作为唯一入口**
- CI / README / Dockerfile 外层 / 本地开发统一调 `make <target>`，禁止直接 `go build` / `docker build` / `kubectl apply`
- 版本号 / 镜像 tag 用变量注入，禁止硬编码
- 生产部署 target 必须有审批保护

### 可观测性
- 所有对外服务必须暴露 `/healthz`、`/readyz`、`/metrics`
- 日志结构化（slog / zap）+ `trace_id`，ERROR 包含完整 error chain
- 高基数字段（user_id、email、url）禁止作为 Prometheus label
- 敏感字段禁止明文入日志

### 安全
- 密码必须用 bcrypt / argon2id，禁止 MD5 / SHA1
- SQL 全部参数化，禁止字符串拼接
- 密钥禁止进代码仓库 / 镜像 / 日志
- 容器以非 root 用户运行
- 多租户接口强制 `tenant_id` 过滤
- CI 必须包含 `govulncheck` + 依赖 / 镜像漏洞扫描

### 运维
- 任何变更必须有回滚方案
- 告警规则必须配 Runbook 链接
- 高风险变更走金丝雀或 feature flag
- P0 / P1 事故必须产出 blameless postmortem

### 数据存储
- **MySQL**：生产 schema 变更走 migration 文件；大表用在线 DDL 工具；变更兼容滚动发布（expand-contract）
- **Redis**：所有 key 必须设 TTL；禁止大 key（value > 10KB / 集合 > 5000）；分布式锁必须有 owner 校验
- **ClickHouse**：必须 Replicated engine；写入必须批量；ORDER BY 从低基数到高基数
- **InfluxDB**：tag 必须低基数（user_id / url 等禁止做 tag）；bucket 必须有 retention
- PII 字段加密存储，测试环境禁止生产数据明文

---

## 需求载体选择

不是所有变更都要写 PRD。按变更类型选载体（详见 `spec/01-requirement/`）：

| 变更类型 | 载体 |
|---------|------|
| Bug / 小改 / 配置 / 文档修复 | Issue（issue tracker） |
| 重构 / 升级依赖 / 性能优化（用户不感知） | RFC（`docs/rfc/RFC-XXX-*.md`） |
| 用户可感知的功能 / 业务变更 | PRD（`docs/requirements/PRD-XXX-*.md`） |
| 跨多个 PRD 的战略 | Epic（`docs/requirements/EPIC-XXX-*.md`） |

---

## 输出语言

默认中文（代码注释、文档、commit message）。

---

完整规范、所有子主题的具体细节、模板和自查清单见 `spec/spec.md` 的任务路由表。
