---
name: gospec
description: "Go 后端 SDLC 全流程中文规范。覆盖 Bounded Context 切分、Kratos 风格分层（cmd/server/service/biz/data/model）、API 设计、数据模型（MySQL / Redis / ClickHouse / InfluxDB）、测试、CI/CD、日志指标追踪 SLO、认证密钥安全、部署与事故、数据库 migration、PRD/RFC/ADR/HLD 文档。框架中性——Web 框架可选 Kratos / gin / Hertz / chi / echo，规范只约束分层和依赖方向。写或审查 Go 代码时按需加载。Go backend SDLC spec — framework-neutral, load on demand for coding/design/testing/ops/docs."
license: MIT
---

# gospec

## 如何使用本 Skill

本 Skill 采用**渐进式披露**：详细规范按 SDLC 阶段拆分在 `spec/` 目录，**按需加载，不要一次性读完**。

1. **第一步**：根据用户当前任务，读 `spec/spec.md` 中的"任务路由表"，找到该任务对应的必读文件
2. **第二步**：只读路由表指定的 1-3 个文件，不要顺序读全部
3. **第三步**：实施 + 对照文件末尾的"自查清单"

## 首次在新项目中激活时

如果检测到当前是首次在某个项目中使用本 skill，**主动检查项目根目录是否有 `AGENTS.md`**：

- **有** → 直接按上面的工作流推进
- **没有** → 提示用户："要不要从 `docs/templates/project-agents-template.md` 创建一份项目根 `AGENTS.md`？这样 Cursor / Cline / Codex / Gemini CLI / Copilot 等其他 agent 打开本项目时也能识别 gospec 规范。" 用户同意后用 Read + Write 把模板复制到项目根。

这样无论用户是通过 `npx skills add singchia/gospec`（标准安装，不会自动放 AGENTS.md）还是 `bash <(curl .../install.sh)`（会自动放），最终都能让所有 agent 看到本项目用了 gospec。

## 技术栈（示例，非强制）

规范**只约束分层和依赖方向**，不锁框架。下表是参考选型，项目可按团队约定替换。

| 领域 | 参考选型 | 常见替换 |
|------|---------|---------|
| 语言 | Go 1.21+ | — |
| Web 框架 | Kratos v2 | gin / Hertz / chi / echo / 原生 net/http |
| ORM | gorm.io/gorm | sqlx / ent / sqlc |
| API 协议 | Protobuf v3 + gRPC + HTTP/REST | OpenAPI + REST |
| 认证 | JWT (golang-jwt/jwt v5) | Auth0 / Keycloak / Casdoor / 自研 |
| 日志 | log/slog（Go 1.21+ 推荐） | zap |
| 指标 | prometheus/client_golang | OpenTelemetry metrics |
| 追踪 | OpenTelemetry | — |
| 测试 | testing + stretchr/testify | — |
| API 文档 | swaggo/swag | grpc-gateway openapi |

## 入口文件

**Agent 拿到任务后第一步**：读 `spec/spec.md`。它包含完整的"任务 → 必读文件"路由表和不可违反的核心约束。

其他文件按路由表按需加载，不要主动读取。

## 文档模板

只有用户需要创建对应文档时再读：

- `docs/templates/product-requirement-template.md` — 产品需求文档（PRD）
- `docs/templates/technical-rfc-template.md` — 技术 RFC
- `docs/templates/architecture-decision-record-template.md` — 架构决策记录（ADR）
- `docs/templates/high-level-design-template.md` — 概要设计文档（HLD）
- `docs/templates/pull-request-template.md` — Pull Request

## 输出语言

默认中文（代码注释、文档、commit message）。
