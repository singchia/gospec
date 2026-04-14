# AGENTS.md — go-best-practices

## 规范入口

**唯一入口**：`spec/spec.md`

它包含一张"任务 → 必读文件"路由表。Agent 拿到任务后：

1. 读 `spec/spec.md`
2. 在路由表里找到当前任务
3. 只读路由表指定的 1-3 个文件
4. 实施 + 对照文件末尾的"自查清单"

**不要顺序读完所有 spec 文件**——这违背渐进式披露原则，浪费上下文。

## 触发条件

当以下场景出现时，Agent 应自动激活此 Skill：

- 创建或初始化 Go 项目
- 编写、审查、重构 Go / gRPC / HTTP 代码
- 设计 API、数据模型、架构
- 写测试、配置 CI/CD
- 配置日志 / 指标 / 追踪 / 告警 / SLO
- 处理认证授权、密钥、依赖漏洞、容器安全、隐私合规
- 设计部署 / 回滚 / feature flag / Runbook / Postmortem
- 编写数据库 migration、backfill、数据保留策略
- 创建 PRD / ADR / HLD
- 生成 Git commit message

## 行为约束

1. **任务开始**：先读 `spec/spec.md` 路由表
2. **按需加载**：只读路由表指定的文件
3. **强制约束**：`spec/spec.md` 的"核心约束"不可违反，即使没读对应详情文件
4. **文档创建**：使用 `docs/templates/` 中的对应模板
5. **输出语言**：默认中文

## 目录结构

```
spec/
├── spec.md                      # 入口（路由表 + 核心约束）
├── 01-requirement/              # 需求（issue/rfc/prd/epic/lifecycle）
├── 02-architecture/             # 架构（layering / monorepo / adr-hld）
├── 03-api/                      # API（proto/http/middleware/versioning）
├── 04-data-model/               # 数据模型（mysql/redis/clickhouse/influxdb）
├── 05-coding/                   # 编码（naming/errors/concurrency/patterns/style）
├── 06-testing/                  # 测试（unit/integration/fuzz-bench）
├── 07-code-review.md            # PR 自查清单
├── 08-delivery/                 # 交付（git/cicd/release）
├── 09-documentation.md          # 文档管理
├── 10-observability/            # 日志 / 指标 / 追踪 / SLO
├── 11-security/                 # 认证 / 输入 / 密钥 / 隐私 / 威胁建模
├── 12-operations/               # 部署 / 事故 / 容量 / 备份
└── 13-database-migration/       # migration / 在线 DDL / 数据治理
```

每个子目录都有 `README.md` 作为该主题的二级路由。

## 模板文件

| 文件 | 用途 |
|------|------|
| `docs/templates/product-requirement-template.md` | 产品需求文档（PRD） |
| `docs/templates/technical-rfc-template.md` | 技术 RFC |
| `docs/templates/architecture-decision-record-template.md` | 架构决策记录（ADR） |
| `docs/templates/high-level-design-template.md` | 概要设计文档（HLD） |
| `docs/templates/pull-request-template.md` | Pull Request 模板 |

## 优先级

- 与其他 Skill 冲突时，以本 Skill 为准
- `spec/` 详细规范优先于 `SKILL.md` / `AGENTS.md` 的概述
- 模板可按项目调整，结构不可删减
