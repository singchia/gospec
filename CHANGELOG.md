# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-04-18

### Added

- **新 spec：`spec/08-delivery/makefile.md`** — 把"所有构建 / 产物 / 部署目标必须由根 Makefile 作为唯一入口"写成红线。覆盖：必备 target 矩阵（`help` / `tools` / `proto` / `build[-%]` / `image[-%]` / `test-*` / `lint` / `migrate-*` / `deploy-<env>` / `clean` / `release`）、命名规范、自文档 `help`、版本 / commit / build-time 注入、per-service 模板（`cmd/*` 自动识别）、shell 严格模式、macOS / Linux 兼容、工具版本锁定、生产部署审批保护、最小可用模板、反模式、自查清单。
- **核心约束新增"构建 / 交付"段**（`spec/spec.md` / `08-delivery/README.md` / `docs/templates/project-agents-template.md` / `docs/templates/cursor-rule-template.mdc` 四处同步）：CI / README / 本地开发统一调 `make <target>`，禁止直接 `go build` / `docker build` / `kubectl apply`；版本号 / 镜像 tag 变量注入；生产部署 target 必须有审批保护。
- **路由表条目**：`spec/spec.md` 和 `spec/08-delivery/README.md` 加"写 / 改 Makefile"路由。

### Changed

- **`spec/02-architecture/monorepo.md`**：原"Makefile 统一入口"小节由具体片段改为引用 `makefile.md`，避免两处维护；"加新服务流程"说明如果用了 `build-%` 模板 Makefile 会自动识别。
- **`spec/03-api/proto.md`**：proto 生成步骤的 makefile 片段收敛为"调 `make proto`"，禁止 CI / README 里直接写 `protoc ...` 命令。
- **`spec/08-delivery/cicd.md`**：CI 示例全部改为 `make tools` / `make lint` / `make vet` / `make build` / `make cover` / `make vuln`，无直接 `go build` / `go test` / `govulncheck`；自查清单加"CI step 只调 make"一条。
- **`spec/08-delivery/release.md`**：多平台构建改为 `make build-cross`，镜像 / 推送 / 签名改为 `make image` / `make image-push` / `make image-sign`，CI YAML 里不再有 `go build` / `docker buildx` / `cosign sign` 直接命令。

## [0.3.0] - 2026-04-18

### Changed (BREAKING — 去特化 / 去框架锁定)

**核心约束重写**：从 liaison-cloud 项目特化口径换成社区通用口径，规范只约束分层和依赖方向，**不锁框架**。

- **分层命名换 Kratos 风格**：`cmd → web → controlplane → repo → model` ⇒ `cmd → server → service → biz → data → model`。
  - `web` → `service`（Handler 层）
  - `controlplane` → `biz`（业务用例 / 领域服务）
  - `repo` → `data`（数据访问层）
  - 新增规则："`service` 不能直连 `data`，必须过 `biz`"
  - 映射表覆盖 Clean Arch / go-zero 风格，项目可按团队约定替换，规范只要求**选一套坚持到底**。
- **monorepo 按 Bounded Context 切分**：`cmd/` 按 service 切（命名 `<bc>-<role>`），`internal/` 按 Bounded Context 切（DDD 限界上下文，5k~30k LOC）；跨 BC 禁止直接 import，走 API / 事件 / `internal/pkg/`。`internal/shared/` 改名 `internal/pkg/`。新增"MVP 阶段可扁平化"和"什么时候升级回 domain-first"指引。
- **Web 框架不锁死**：显式支持 Kratos v2 / gin / CloudWeGo Hertz / chi / echo / 原生 net/http。`server/` 层装配细节依框架而定，`03-api/middleware.md` 和 `03-api/http.md` 都给了 Kratos + gin 两套示例。
- **技术栈表加"参考选型 / 常见替换"两列**：SKILL.md / README.md / README.en.md / `05-coding/README.md` 四处同步。
  - 认证从 "Casdoor + JWT" 改为 "JWT + (Auth0 / Keycloak / Casdoor / 自研)"。
  - `gorilla/mux` 标注"2022 年已归档，不建议新项目使用"。
  - `gopkg.in/yaml.v2` 换成 `yaml.v3` / viper / koanf / envconfig。
  - 进程管理从 `armorigo/sigaction`（作者自建库）换成标准库 `signal.NotifyContext`。
- **全量替换代码示例里的项目特化词**：`liaison` → `foo` / `order`；`Edge` / `CreateEdge` → `Order` / `CreateOrder`；`IAMService` → `UserUsecase`；`lerrors` → `errs`；proto package `liaison.v1` → `order.v1`；Redis namespace `liaison:` → `foo:`；ClickHouse `liaison.events` → `foo.events`；InfluxDB `liaison-metrics` → `foo-metrics`；cmd 入口 `cmd/manager/` → `cmd/order-api/`。
- **SKILL.md description 改写**：去掉 "Kratos / gRPC / GORM / MySQL / Redis / ClickHouse / InfluxDB" 的硬性列举，改成"框架中性，Web 框架可选 Kratos / gin / Hertz / chi / echo"。
- **HLD 模板模块表更新**：按新分层重写 `internal/<bc>/{server,service,biz,data,model}` 映射表。
- **Cursor 规则模板同步**：`docs/templates/cursor-rule-template.mdc` 的核心约束同步新分层和 BC 切分。

### Migration note

升级到 0.3.0 后，如果你的项目延续了旧的 `web/controlplane/repo` 目录命名，**不需要立刻重构**——规范提供了 Kratos / Clean Arch / go-zero 三套风格的映射表，选一套坚持到底即可。核心约束（依赖单向、handler 不直连 data、跨 BC 不 import）新旧命名都适用。

## [0.2.0] - 2026-04-15

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
