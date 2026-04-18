# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **SKILL.md `description` 大幅缩短**（~1024 字符 → ~250 字符），提升 agent 激活匹配准确率。
- **软化 3 条过严的"强制约束"**，与 Go 生态实际一致：
  - `init()` 改为"仅允许做注册（pprof / collector / driver），禁止 IO 或可能 panic"
  - `interface{}` 改为"避免出现在公共 API 边界，解码 / SDK 适配等不可避免场景就近注释"
  - `utils/` 改为"仅作最后兜底，优先按职责拆 `mathx/` / `strx/`"
- 三处同步更新：`spec/spec.md` / `spec/05-coding/README.md` / `docs/templates/project-agents-template.md`。
- **CI 切到 `--strict` 模式**，路由表完整性 + 自查清单缺失视为失败，防 spec 漂移。

### Added (Cursor 体验)

- **`docs/templates/cursor-rule-template.mdc`**：Cursor 单文件规则模板，自带 `globs: [**/*.go, **/*.proto, ...]` + `alwaysApply: false`，让 Cursor 在编辑相关文件时自动附加，**避免每次让用户手动选择规则**。
- **`scripts/install.sh` 同时落 `.cursor/rules/gospec.mdc`**，可通过 `NO_CURSOR=1` 跳过；本地落后远端时自动提示更新命令。

### Added (校验强化)

- **路由表完整性校验**：`scripts/validate-skill.py` 检查 `spec/spec.md` 路由表里引用的所有 spec 子文件是否真实存在，防 broken link。
- **自查清单存在校验**：每个 spec 子文件须有 `## 自查` / `## Checklist` 标题小节，否则在 `--strict` 模式下报错。已为缺失的两个文件补上（`spec/09-documentation.md`、`spec/01-requirement/lifecycle.md`）；`spec/07-code-review.md` 整体即为 PR 自查清单，列入例外。
- **install.sh 端到端冒烟测试**：CI 模拟在干净目录运行 install.sh，校验 `AGENTS.md` 和 `.cursor/rules/gospec.mdc` 落盘 + frontmatter 正确。

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
  - `SKILL.md` 含 frontmatter `name` + `description` + `license`，符合 [skills.sh](https://skills.sh) Open Agent Skills 协议
  - 支持 `npx skills add singchia/gospec` 标准入口
  - SKILL.md 含"首次激活检查 AGENTS.md"指引：通过 `npx skills add` 安装的用户首次使用时，agent 会主动询问是否在项目根创建 AGENTS.md
  - `scripts/install.sh` 一行命令安装 + 在用户项目根创建 `AGENTS.md`（与 npx skills 互补，提供更主动的 AGENTS.md 落地）
  - `docs/templates/project-agents-template.md` 项目根 AGENTS.md 模板，inline 核心约束
  - `scripts/build-skill.sh` 自包含构建脚本（依赖 bash + python3 + pyyaml + zip），产出 `dist/gospec.skill`（~140KB / 84 entries）
  - `scripts/validate-skill.py` 自包含 frontmatter + 必备文件校验器，与 skill-creator/quick_validate.py 规则对齐
- **CI/CD**：
  - `.github/workflows/validate.yml` 每次 push / PR 校验 SKILL.md frontmatter + smoke test 构建
  - `.github/workflows/release.yml` tag push 自动构建 `gospec.skill` 并创建 GitHub Release，附带 .skill 资产 + 自动生成的 release notes
