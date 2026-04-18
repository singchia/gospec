# 09 - 文档管理规范

> **适用**：建立 / 维护项目文档目录、管理 PRD/ADR/HLD/Runbook/Postmortem 等文档归档位置。
>
> **核心**：文档与代码同仓管理，PR 中同步提交，禁止文档与代码脱节。

## 文档目录结构

```
docs/
├── requirements/           # 需求文档（PRD / Epic）  → spec/01-requirement/
│   ├── PRD-001-*.md
│   └── EPIC-001-*.md
├── rfc/                    # 技术 RFC               → spec/01-requirement/technical-rfc.md
│   └── RFC-001-*.md
├── adr/                    # 架构决策记录           → spec/02-architecture/architecture-decision-record.md
│   └── ADR-001-*.md
├── design/                 # 设计文档               → spec/02-architecture/high-level-design.md
│   ├── HLD-XXX-*.md
│   └── LLD-XXX-*.md
├── swagger/                # Swagger 生成（禁止手改）→ spec/03-api/
│   └── docs.go
├── diagrams/               # 架构图
│   └── *.png / *.drawio
├── business/               # 业务说明文档
├── guides/                 # 开发指南
│   ├── getting-started.md
│   └── deployment.md
├── slo/                    # SLO 定义               → spec/10-observability/slo-alerting.md
│   └── <service>.md
├── runbooks/               # 告警处置手册           → spec/12-operations/incident.md
│   └── <alert-name>.md
├── postmortems/            # 事后复盘               → spec/12-operations/incident.md
│   └── YYYY-MM-DD-*.md
├── security/               # 威胁建模               → spec/11-security/threat-model.md
│   └── threat-model-<service>.md
└── ops/                    # 运维记录
    ├── change-freeze.md    # 变更冻结公告           → spec/12-operations/deployment.md
    ├── loadtest-*.md       # 压测报告               → spec/12-operations/capacity.md
    ├── chaos-*.md          # 混沌演练记录           → spec/12-operations/capacity.md
    └── dr-drill-*.md       # 灾难恢复演练           → spec/12-operations/backup-dr.md
```

---

## 各类文档职责

| 类型 | 路径 | 编写时机 | 编写方 |
|------|------|---------|--------|
| Epic | `docs/requirements/` | 战略级需求 | 产品 + 管理层 |
| PRD | `docs/requirements/` | 功能开发前 | 产品 |
| RFC | `docs/rfc/` | 纯技术变更前 | 技术 |
| ADR | `docs/adr/` | 架构决策时 | 技术 |
| HLD | `docs/design/` | 复杂功能设计阶段 | 技术 |
| Swagger | `docs/swagger/` | 自动生成 | 工具 |
| 开发指南 | `docs/guides/` | 环境/流程变更时 | 技术 |
| SLO | `docs/slo/` | 服务上线前 | 技术 + SRE |
| Runbook | `docs/runbooks/` | 新告警上线前 | 值班 + 研发 |
| Postmortem | `docs/postmortems/` | P0/P1 事故 48h 内 | IC + Scribe |
| 威胁建模 | `docs/security/` | 新服务/新认证机制上线前 | 技术 + 安全 |
| 运维记录 | `docs/ops/` | 压测/混沌/演练后 | 值班 + SRE |

---

## 文档编号规则

| 类型 | 格式 | 示例 |
|------|------|------|
| Epic | `EPIC-<三位序号>-<简述>` | `EPIC-001-billing-platform` |
| PRD | `PRD-<三位序号>-<简述>` | `PRD-001-user-email-verification` |
| RFC | `RFC-<三位序号>-<简述>` | `RFC-001-migrate-to-slog` |
| ADR | `ADR-<三位序号>-<简述>` | `ADR-001-use-kratos-over-gin` |
| HLD | `HLD-<三位序号>-<简述>` | `HLD-001-billing-system` |

---

## 文档维护规则

- **新功能开发前**必须有明确的需求描述（PRD 或 issue）
- **涉及架构变更**必须有 ADR，先写后改代码
- **API 变更**先更新 `.proto` 文件（唯一数据源），Swagger 自动生成
- **`README.md`** 保持最新的快速上手指引，随项目演进同步更新
- **部署文档**随配置变更同步更新（`.env.example`、docker-compose、端口说明）
- **禁止手动修改** `docs/swagger/` 下的生成文件

---

## spec/ 目录说明

`spec/` 目录是给 AI Agent 使用的项目规范，按 SDLC 阶段组织：

```
spec/
├── spec.md                       # 入口（路由表 + 核心约束）
├── 01-requirement/               # 需求（issue/rfc/prd/epic/lifecycle）
├── 02-architecture/              # 架构（layering / monorepo / adr-hld）
├── 03-api/                       # API（proto/http/middleware/versioning）
├── 04-data-model/                # 数据模型（mysql/redis/clickhouse/influxdb）
├── 05-coding/                    # 编码（naming/errors/concurrency/patterns/style）
├── 06-testing/                   # 测试（unit/integration/fuzz-bench）
├── 07-code-review.md             # PR 自查清单
├── 08-delivery/                  # 交付（git/cicd/release）
├── 09-documentation.md           # 文档管理（本文件）
├── 10-observability/             # 日志 / 指标 / 追踪 / SLO
├── 11-security/                  # 认证 / 输入 / 密钥 / 隐私 / 威胁建模
├── 12-operations/                # 部署 / 事故 / 容量 / 备份
└── 13-database-migration/        # migration / 在线 DDL / 数据治理
```

**规则：** Agent 实现功能前必须先阅读 `spec/spec.md`，按"任务路由表"按需加载相关文件，**不要顺序读完所有 spec**。

---

## AGENTS.md 规范

项目根目录的 `AGENTS.md` 是 AI Agent 的入口约束：

```markdown
# AGENTS.md

Always follow the specification before coding.

Spec entry point: spec/spec.md

Rules:
1. Read spec/spec.md before implementing any feature
2. Follow the SDLC phase order: requirement → architecture → api → data-model → coding → testing → delivery
3. Do not implement features not defined in spec or PRD
4. If spec is unclear, ask before coding
```

---

## 自查

提交 PR 前对照（与 `07-code-review.md` 的"文档"小节互补）：

- [ ] 新功能有对应 PRD 或 issue 关联
- [ ] 架构变更有 ADR
- [ ] API 变更已更新 `.proto`，Swagger 已重新生成
- [ ] `README.md` 如有影响已同步更新
- [ ] `.env.example` 如有新配置项已同步更新
- [ ] 部署配置如有变更已同步更新
- [ ] 文档归位（PRD/RFC 在 `docs/requirements/` 或 `docs/rfc/`，ADR 在 `docs/adr/`，不散落）
- [ ] 文档之间相互引用而非复制（避免 spec 漂移）
