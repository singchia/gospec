---
name: gospec
description: "Go 后端 SDLC 全流程中文规范（Kratos / gRPC / GORM / MySQL / Redis / ClickHouse / InfluxDB）。写或审查 Go 代码、设计 API / 数据模型 / 架构、写测试、配 CI/CD、做日志指标追踪 SLO、处理认证密钥安全、写部署或事故方案、写数据库 migration、起草 PRD / RFC / ADR / HLD 时按需加载。Go backend SDLC spec skill — load on demand for coding, API/schema design, testing, CI/CD, observability, security, ops, DB migration, and PRD/RFC/ADR/HLD docs."
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

## 技术栈

| 领域 | 选型 |
|------|------|
| 语言 | Go 1.21+ |
| Web 框架 | go-kratos/kratos v2 |
| ORM | gorm.io/gorm |
| API | Protocol Buffers v3 + gRPC + HTTP/REST |
| 认证 | Casdoor + JWT |
| 日志 | log/slog (推荐) 或 zap |
| 指标 | Prometheus client_golang |
| 追踪 | OpenTelemetry |
| 测试 | testing + stretchr/testify |
| API 文档 | swaggo/swag |

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
