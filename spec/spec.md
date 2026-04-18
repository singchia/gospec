# Go 项目开发全流程规范

> AI Agent 入口。**先按"任务路由表"判断当前任务，只读必要文件**，避免一次性加载全部规范。

---

## 任务路由表（按需加载）

### 编码 / 实现类

| 当前任务 | 必读 | 按需加载 |
|---------|------|---------|
| 写一个新 HTTP/gRPC handler | `03-api/proto.md` + `03-api/http.md` + `05-coding/errors.md` | `03-api/middleware.md`, `10-observability/logging.md`, `11-security/auth.md` |
| 写业务方法 / Service | `02-architecture/layering.md` + `05-coding/errors.md` | `05-coding/patterns.md`, `06-testing/unit.md`, `10-observability/tracing.md` |
| 设计构造函数 / 依赖注入 / 装饰器 / 重试 | `05-coding/patterns.md` | — |
| 写 goroutine / 用锁 / 传 context | `05-coding/concurrency.md` | `05-coding/patterns.md` |
| 命名变量 / 函数 / 包 | `05-coding/naming.md` | — |
| 处理错误、用 `%w` 包装 | `05-coding/errors.md` | — |
| 写 MySQL GORM 模型 / DAO | `04-data-model/mysql.md` + `05-coding/errors.md` | `13-database-migration/migration.md` |
| 用 Redis 做缓存 / 锁 / 限流 | `04-data-model/redis.md` | — |
| 写 ClickHouse 表 / 聚合查询 | `04-data-model/clickhouse.md` | — |
| 写 InfluxDB measurement / 监控指标 | `04-data-model/influxdb.md` | `10-observability/metrics.md` |
| 写单元测试 | `06-testing/unit.md` | — |
| 写集成测试 / E2E | `06-testing/integration.md` | — |
| 写 fuzz / benchmark | `06-testing/fuzz-bench.md` | — |
| 处理用户输入 / 外部 URL / 文件 | `11-security/input-crypto.md` | — |
| 实现登录 / 鉴权 | `11-security/auth.md` | `11-security/input-crypto.md`, `03-api/middleware.md` |
| 涉及密钥 / 加密字段 | `11-security/secrets-supply-chain.md` | `11-security/input-crypto.md` |
| 处理 PII / 个人数据 | `11-security/privacy-audit.md` | — |

### 设计 / 文档类

| 当前任务 | 必读 |
|---------|------|
| 不知道写 issue / RFC / PRD / Epic 哪个 | `01-requirement/README.md` |
| 写 / 处理 issue | `01-requirement/issue.md` |
| 写技术 RFC | `01-requirement/technical-rfc.md` |
| 写 PRD（产品需求） | `01-requirement/product-requirement.md` |
| 写 Epic | `01-requirement/epic.md` |
| 状态流转 / 变更追溯 / 上线复盘 | `01-requirement/lifecycle.md` |
| 设计单服务内部分层 | `02-architecture/layering.md` |
| 初始化 monorepo / 加新服务 / 配 CODEOWNERS | `02-architecture/monorepo.md` |
| 写 ADR（架构决策） | `02-architecture/architecture-decision-record.md` |
| 写 HLD（概要设计）/ 走新服务上线 checklist | `02-architecture/high-level-design.md` |
| 设计 API（proto 优先） | `03-api/proto.md` + `03-api/http.md` |
| 设计 API 版本演进 / 废弃 / 幂等 | `03-api/versioning.md` |
| 选数据存储（MySQL/Redis/CH/Influx） | `04-data-model/README.md` |
| 文档归档 | `09-documentation.md` |

### 数据 / 数据库类

| 当前任务 | 必读 |
|---------|------|
| 加 / 改 MySQL 字段、写 migration | `13-database-migration/migration.md` |
| 大表 DDL、回填历史数据 | `13-database-migration/online-ddl.md` |
| 数据保留策略、账号权限 | `13-database-migration/data-governance.md` |

### 可观测性

| 当前任务 | 必读 |
|---------|------|
| 加日志 / 决定日志级别 | `10-observability/logging.md` |
| 加 Prometheus 指标 | `10-observability/metrics.md` |
| 加 OpenTelemetry span | `10-observability/tracing.md` |
| 写告警规则 / 定 SLO / 健康检查 | `10-observability/slo-alerting.md` |

### 交付 / 运维类

| 当前任务 | 必读 |
|---------|------|
| Git commit / 分支命名 / 工作流 / 本地起服务 | `08-delivery/git.md` |
| 配置 CI/CD pipeline / golangci-lint / pre-commit / 分支保护 | `08-delivery/cicd.md` |
| 发版 / 多平台构建 / 镜像签名 / 生产审批 | `08-delivery/release.md` |
| 部署 / 回滚 / feature flag | `12-operations/deployment.md` |
| 写 Runbook / 事故响应 / Postmortem | `12-operations/incident.md` |
| 容量评估 / 压测 / 混沌 | `12-operations/capacity.md` |
| 备份 / 灾难恢复 | `12-operations/backup-dr.md` |

### 综合 / 入口

| 当前任务 | 必读 |
|---------|------|
| PR 提交前自查 | `07-code-review.md` |
| 项目初始化 / 不知道从哪开始 | 本文件 + `02-architecture/monorepo.md` + `02-architecture/layering.md` + `05-coding/README.md` |

---

## 完整规范索引

```
spec/
├── spec.md                       # 本文件（路由 + 核心约束）
├── 01-requirement/               # 需求
│   ├── README.md                          # 载体分级 + 决策树
│   ├── issue.md                           # Issue 用法 + 升级规则
│   ├── technical-rfc.md                   # 技术 RFC 流程（模板见 docs/templates/）
│   ├── product-requirement.md             # PRD 流程（模板见 docs/templates/）
│   ├── epic.md                            # 战略 Epic 流程
│   └── lifecycle.md                       # 状态流转 / 变更追溯 / 复盘
├── 02-architecture/              # 架构
│   ├── README.md
│   ├── layering.md                        # 单服务内分层
│   ├── monorepo.md                        # 仓库结构 / module / CODEOWNERS / affected
│   ├── architecture-decision-record.md    # ADR 流程
│   └── high-level-design.md               # HLD 流程 + 新服务 checklist
├── 03-api/                       # API 设计
│   ├── README.md
│   ├── proto.md                  # Proto 优先 / 命名 / 代码生成
│   ├── http.md                   # REST 路由 / 响应 / 错误映射
│   ├── middleware.md             # Swagger 注释 / 认证中间件
│   └── versioning.md             # 版本演进 / 幂等 / 限流响应 / 批量
├── 04-data-model/                # 数据模型
│   ├── README.md                 # 选型决策
│   ├── mysql.md                  # GORM / DAO / 事务 / 索引
│   ├── redis.md                  # Key / TTL / 数据类型 / 分布式锁
│   ├── clickhouse.md             # MergeTree / 分区 / 物化视图
│   └── influxdb.md               # measurement / tag / retention
├── 05-coding/                    # 编码
│   ├── README.md                 # 技术栈 / 全局禁止
│   ├── naming.md                 # 命名约定
│   ├── errors.md                 # 错误处理
│   ├── concurrency.md            # goroutine / lock / context / channel
│   ├── patterns.md               # 设计模式
│   └── style.md                  # import / 注释 / struct
├── 06-testing/                   # 测试
│   ├── README.md                 # 分层 / 覆盖率
│   ├── unit.md                   # 单元 / table-driven / mock
│   ├── integration.md            # 集成 / E2E / testcontainers
│   └── fuzz-bench.md             # fuzz / benchmark / 安全测试
├── 07-code-review.md             # PR 自查清单
├── 08-delivery/                  # 交付
│   ├── README.md
│   ├── git.md                    # commit / branch / workflow
│   ├── cicd.md                   # pipeline / lint / pre-commit
│   └── release.md                # 多平台 / 签名 / 生产审批
├── 09-documentation.md           # 文档结构 / 模板
├── 10-observability/             # 可观测性
│   ├── README.md
│   ├── logging.md
│   ├── metrics.md
│   ├── tracing.md
│   └── slo-alerting.md
├── 11-security/                  # 安全
│   ├── README.md
│   ├── auth.md
│   ├── input-crypto.md
│   ├── secrets-supply-chain.md
│   ├── privacy-audit.md
│   └── threat-model.md
├── 12-operations/                # 运维 / 事故
│   ├── README.md
│   ├── deployment.md
│   ├── incident.md
│   ├── capacity.md
│   └── backup-dr.md
└── 13-database-migration/        # DB 迁移 / 治理
    ├── README.md
    ├── migration.md
    ├── online-ddl.md
    └── data-governance.md
```

---

## Agent 行为约定

1. **开始任何任务前**：查上面的路由表，确定本次需要读哪些文件
2. **不要预读所有 spec**：渐进式按需加载
3. **需求不明确时**：提问而非自行假设
4. **涉及架构变更**：先写 ADR，确认后再编码
5. **涉及 API 变更**：先更新 `.proto`，禁止改生成文件
6. **涉及数据变更**：先设计表结构 + migration，再写代码
7. **提交 PR 前**：对照 `07-code-review.md` 自查
8. **所有输出**：默认中文（代码注释、文档、提交信息）

---

## 核心约束（不可违反）

> 这些是任何任务都要遵守的红线，即使没读对应文件。

### 架构
- 单服务内：`cmd → web → controlplane → repo → model`，禁止跨层调用
- monorepo 内：`internal/<domain>` 之间禁止直接 import，必须通过 API / 事件 / `internal/shared/`
- 接口在消费方定义，禁止循环依赖
- `utils/`、`lerrors/` 不依赖任何业务包
- 依赖通过构造函数注入，不使用全局变量
- 每个目录都被 CODEOWNERS 覆盖

### 编码
- 禁止 `_ = fn()` 忽略错误（确实想丢弃错误必须有注释说明）
- 共享状态必须加锁，测试必须带 `-race`
- 错误不重复记录：要么处理，要么向上传播
- 所有涉及 IO 的函数第一个参数为 `context.Context`
- `init()` 仅允许做注册（pprof / metrics collector / driver 等），禁止做 IO 或可能 panic 的逻辑
- 避免 `any` / `interface{}` 出现在公共 API 边界（解码、SDK 适配等不可避免场景除外）
- `utils/` 仅作最后兜底，优先按职责拆 `mathx/`、`strx/` 等

### API
- 所有 API 变更先更新 `.proto`，不直接修改生成代码
- Handler 必须有 Swagger 注释：`@Summary`、`@Router`、`@Success` 缺一不可
- 响应格式统一：`{code, message, data}`
- 破坏性变更走新版本，原版本只允许加非破坏性内容

### 测试
- 新功能必须有单元测试
- CI 强制启用 `-race`
- E2E 测试必须清理数据

### Git
- 提交格式：`<type>(<scope>): <desc>`
- 禁止提交敏感信息（密码、密钥、token）
- 禁止 force push main/master

### 可观测性
- 所有对外服务必须暴露 `/healthz`、`/readyz`、`/metrics`
- 日志结构化 + `trace_id`，ERROR 包含完整 error chain
- 高基数字段（user_id、email）禁止作为 Prometheus label
- 敏感字段禁止明文入日志

### 安全
- 密码必须用 bcrypt/argon2id，禁止 MD5/SHA1
- SQL 全部参数化，禁止字符串拼接
- 密钥禁止进代码仓库 / 镜像 / 日志
- 容器以非 root 运行
- 多租户接口强制 `tenant_id` 过滤

### 运维
- 任何变更必须有回滚方案
- 告警规则必须配 Runbook 链接
- 高风险变更走金丝雀或 feature flag
- P0/P1 事故必须产出 blameless postmortem

### 数据存储
- **MySQL**：生产 schema 变更走 migration 文件；大表用在线 DDL 工具；变更兼容滚动发布
- **Redis**：所有 key 必须设 TTL；禁止大 key（value > 10KB / 集合 > 5000）；分布式锁必须有 owner 校验
- **ClickHouse**：必须 Replicated engine；写入必须批量；ORDER BY 从低基数到高基数
- **InfluxDB**：tag 必须低基数（user_id/url 等禁止做 tag）；bucket 必须有 retention
- **通用**：PII 字段加密存储，测试环境禁止生产数据明文
