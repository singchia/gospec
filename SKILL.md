---
name: gospec
description: "Go 后端项目 SDLC 全流程中文规范（基于 go-kratos / GORM / Protobuf / OpenTelemetry / Prometheus）。覆盖需求 / 架构 / API / 数据模型（MySQL Redis ClickHouse InfluxDB） / 编码 / 测试 / 代码审查 / 交付 / 文档 / 可观测性 / 安全 / 运维 / 数据库迁移 13 个阶段。当用户创建 Go 项目、写或审查 Go 代码、设计 gRPC/HTTP API、设计数据模型、写测试、配置 CI/CD、设计监控告警 SLO、处理安全 密钥 合规、写部署或事故响应方案、写数据库 migration、撰写 PRD RFC ADR HLD 文档时使用。适用于云原生后端、IoT 平台、微服务、单仓 monorepo 项目。"
license: MIT
---

# gospec

## 如何使用本 Skill

本 Skill 采用**渐进式披露**：详细规范按 SDLC 阶段拆分在 `spec/` 目录，**按需加载，不要一次性读完**。

1. **第一步**：根据用户当前任务，读 `spec/spec.md` 中的"任务路由表"，找到该任务对应的必读文件
2. **第二步**：只读路由表指定的 1-3 个文件，不要顺序读全部
3. **第三步**：实施 + 对照文件末尾的"自查清单"

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
