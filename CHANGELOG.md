# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **SDLC spec 骨架**（`spec/`）：覆盖从需求到运维的 13 个阶段，每阶段按主题拆分为子文件，通过 `spec/spec.md` 的任务路由表按需加载。
- **需求规范**（`spec/01-requirement/`）：区分 Issue / RFC / PRD / Epic 四种载体，含升级规则、状态门禁、变更追溯、上线复盘流程。
- **架构规范**（`spec/02-architecture/`）：单服务分层 + monorepo 仓库结构 + ADR + HLD + 新服务上线 checklist。
- **API 规范**（`spec/03-api/`）：Proto 优先、HTTP 路由、响应格式、错误映射、Swagger、认证中间件、版本演进 / 幂等 / 限流响应。
- **数据模型规范**（`spec/04-data-model/`）：MySQL / Redis / ClickHouse / InfluxDB 四种存储的设计约束。
- **编码规范**（`spec/05-coding/`）：命名、错误处理、并发、设计模式（10 个）、风格。
- **测试规范**（`spec/06-testing/`）：单元 / 集成 / E2E / testcontainers / fuzz / benchmark。
- **PR 自查清单**（`spec/07-code-review.md`）。
- **交付规范**（`spec/08-delivery/`）：Conventional Commits、分支、工作流、CI/CD（含 golangci-lint / govulncheck / trivy / cosign）、发版。
- **文档管理规范**（`spec/09-documentation.md`）。
- **可观测性规范**（`spec/10-observability/`）：结构化日志、Prometheus 指标、OpenTelemetry、SLO 与告警。
- **安全规范**（`spec/11-security/`）：认证授权、输入校验与加密、密钥与供应链、隐私与审计、威胁建模。
- **运维与事故响应**（`spec/12-operations/`）：部署策略、on-call 与事故响应、容量与混沌、备份与灾难恢复。
- **数据库迁移规范**（`spec/13-database-migration/`）：migration 工具、在线 DDL、backfill、数据治理。
- **文档模板**（`docs/templates/`）：PRD / RFC / ADR / HLD / PR 五个模板，与 spec 规则双向引用。
- **Skill 安装机制**：
  - `SKILL.md` 通过 skill-creator 校验，作为 Claude Code skill 加载入口
  - `scripts/install.sh` 一行命令安装 + 在用户项目根创建 `AGENTS.md`
  - `docs/templates/project-agents-template.md` 项目根 AGENTS.md 模板，inline 核心约束
  - `scripts/build-skill.sh` 维护者用，构建 `.skill` 打包产物（约 130KB / 68 文件）
