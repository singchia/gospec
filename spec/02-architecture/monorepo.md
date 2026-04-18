# 02.3 - Monorepo 仓库结构（按 Bounded Context 切分）

> **适用**：初始化 monorepo、加新服务、决定 module 策略、配 CODEOWNERS、配 affected detection。
>
> 本规范参考 [Standard Go Project Layout](https://github.com/golang-standards/project-layout)、Kratos 官方模板，以及 Google / Uber 等大厂 monorepo 实践。

## 先搞清楚两个概念

**service ≠ domain**：

- **service**：一个可部署单元（一个二进制 / 一个容器）
- **domain (Bounded Context)**：一个业务边界（DDD 限界上下文）

它们是多对多的关系：

```
场景 1：1 BC → 1 service（最常见）
  cmd/order-api/main.go  装配  internal/order/{server,service,biz,data,model}

场景 2：1 BC → 多 service（API + worker + cli）
  cmd/order-api/     ┐
  cmd/order-worker/  ├─ 都用 internal/order/{biz,data}
  cmd/order-cli/     ┘

场景 3：1 service → 多 BC（BFF / 网关，谨慎用）
  cmd/bff-web/  装配  internal/{user,order,billing} 的对外接口
```

**顶层切分规则**：
- `cmd/` **按 service 切**——扫一眼知道有几个部署单元
- `internal/` **按 BC 切**——扫一眼知道有几个业务领域

---

## 何时选 monorepo

| 维度 | Monorepo | Polyrepo |
|------|---------|---------|
| 跨服务原子提交 | ✅ 一个 PR 改多服务 | ❌ 跨 PR 协调 |
| 依赖统一升级 | ✅ 一次到位 | ❌ 多 repo 滚动 |
| 代码共享 | ✅ 直接 import internal | ❌ 走库版本号 |
| 跨服务 refactor | ✅ 可原子 | ❌ 难 |
| 构建速度 | ❌ 需 affected detection | ✅ 天然隔离 |
| 权限粒度 | ❌ 粗，靠 CODEOWNERS | ✅ 细，靠 repo 权限 |
| 仓库大小 | ❌ 单仓巨大 | ✅ 各自独立 |
| 适用规模 | < 100 服务、紧耦合团队 | 极大规模 / 跨组织 |

**经验法则**：< 50 个服务 + 同一团队 → monorepo；否则评估。

---

## Bounded Context 是什么粒度

**中等粒度——DDD 的限界上下文 / Subdomain**，不是"整个业务"，也不是"一个用例"。

| 粒度 | 例子 | 对不对 |
|------|------|-------|
| 太大（整个产品） | `internal/ecommerce/` | ❌ 等于没切 |
| **刚好（BC）** | `internal/order/` `internal/iam/` `internal/billing/` `internal/inventory/` `internal/notification/` | ✅ 本规范推荐粒度 |
| 太小（用例 / 功能） | `internal/user_login/` `internal/order_cancel/` | ❌ 这只是 biz 里的一个 method |

### 判定一个 BC 粒度合适的四条标准

1. **独立团队可拥有**（CODEOWNERS 填一个团队，不打架）
2. **有自己的持久化数据**（自己的表 / Kafka topic / stream），不读别人的表
3. **有自己的"行话"**（同一个词在不同 BC 里有不同含义 = 是两个 BC）
4. **未来能独立拆成微服务**而不需要大手术

### 经验值

- Go 代码量：**5k ~ 30k LOC**。< 3k 说明可能只是个功能；> 50k 应该继续拆
- 每个 BC 下面有一套完整 `server/service/biz/data/model`
- 犹豫"该放 A 还是 B"说明边界不清——先写 ADR 再切

### 真实案例参考

- **电商**：`iam` / `catalog` / `cart` / `order` / `payment` / `inventory` / `shipping` / `notification`
- **SaaS**：`tenant` / `billing` / `auth` / `audit` / `feature-flag`
- **IoT 云**：`device` / `iam` / `billing` / `telemetry` / `ota`

---

## 标准目录布局

```
repo-root/
├── api/                             # Proto 定义（按 BC 分组）
│   ├── user/v1/
│   │   └── user.proto
│   ├── order/v1/
│   │   └── order.proto
│   ├── billing/v1/
│   └── buf.yaml                     # buf 工具配置
│
├── cmd/                             # 按 service 切（一个入口一个目录）
│   ├── order-api/                   # order BC 的 HTTP/gRPC 服务
│   │   └── main.go
│   ├── order-worker/                # order BC 的后台消费者
│   │   └── main.go
│   ├── user-api/
│   │   └── main.go
│   └── bff-web/                     # 跨 BC 的 BFF
│       └── main.go
│
├── internal/                        # 仅本仓库使用，Go 编译器强制边界
│   ├── order/                       # Bounded Context 1
│   │   ├── server/                  # HTTP/gRPC Server 装配
│   │   ├── service/                 # Handler（proto impl）
│   │   ├── biz/                     # 业务用例
│   │   ├── data/                    # Repo 实现
│   │   └── model/                   # 领域对象
│   ├── user/                        # Bounded Context 2
│   │   └── ...
│   ├── billing/                     # Bounded Context 3
│   │   └── ...
│   └── pkg/                         # 跨 BC 共享（业务无关）
│       ├── auth/                    # 认证中间件
│       ├── log/                     # slog 封装
│       ├── errs/                    # 通用错误类型
│       ├── trace/                   # OTel setup
│       └── conf/                    # 配置加载
│
├── pkg/                             # 对外公开的库（可选，谨慎）
│   └── client/                      # 给外部用户的 SDK
│
├── deploy/                          # 部署配置
│   ├── docker-compose.yml
│   ├── helm/
│   │   ├── order-api/
│   │   └── user-api/
│   └── k8s/
│
├── db/                              # 数据库 migration
│   └── migrations/
│
├── scripts/
│   ├── proto-gen.sh
│   └── lint.sh
│
├── tools/                           # 内部工具源码（独立 module）
│   ├── codegen/
│   └── mock-server/
│
├── docs/                            # 跨服务文档
│   ├── requirements/  adr/  design/  runbooks/  postmortems/  slo/  security/
│
├── test/                            # 跨服务集成测试 / E2E
│   └── e2e/
│
├── third_party/                     # 必须 vendor 的第三方代码
├── spec/                            # 项目规范
│
├── go.mod
├── go.sum
├── go.work                          # 仅多 module 项目
├── Makefile
├── CODEOWNERS                       # 或 .github/CODEOWNERS
├── .github/
│   └── workflows/
├── .golangci.yml
├── .tool-versions                   # asdf / mise 工具链锁定
└── README.md
```

### 关键目录规则

| 目录 | 职责 | 谁可以 import |
|------|------|--------------|
| `api/` | Proto + 生成代码 | 所有 |
| `cmd/<service>/` | 可执行入口（装配） | 不被 import |
| `internal/<bc>/` | Bounded Context 业务代码 | 仅本 BC + `cmd/` |
| `internal/pkg/` | 跨 BC 共享（业务无关） | 任何 `internal/` |
| `pkg/` | 对外公开 SDK | 任何项目（包括外部） |
| `tools/` | 内部工具 | 不被业务代码 import |
| `third_party/` | vendored 第三方 | 封装后用 |

---

## MVP 阶段可扁平化

只有 1 个 BC 时**省掉** `internal/<bc>/` 这一层：

```
repo-root/
├── api/v1/
├── cmd/api/main.go
├── internal/
│   ├── server/  service/  biz/  data/  model/
│   └── pkg/
├── go.mod
└── ...
```

**什么时候升级回 domain-first**：
- 出现第二个稳定 BC（第二个领域独立出来）
- 出现 worker / cli 等第二个 service 入口（需要拆共享代码）

升级时把现有 `internal/{server,service,biz,data,model}` 挪进 `internal/<首个-bc>/`，其他 BC 新建目录即可。

---

## BC 边界（硬规则）

### 红线

`internal/order/` **禁止** import `internal/user/`，反之亦然。

```go
// ❌ 跨 BC 直接 import
package billing

import "github.com/org/repo/internal/order/model"  // 禁止
```

### 强制方式

1. **Code Review**：CODEOWNERS 强制双 owner review
2. **Linter**：`go-arch-lint` / `import-boundaries` / 自定义脚本
3. **CI 阻断**：linter 失败阻断 PR

```yaml
# .go-arch-lint.yml
version: 3
workdir: .
components:
  order:    { in: internal/order/** }
  user:     { in: internal/user/** }
  billing:  { in: internal/billing/** }
  pkg:      { in: internal/pkg/** }
deps:
  order:    { mayDependOn: [pkg] }
  user:     { mayDependOn: [pkg] }
  billing:  { mayDependOn: [pkg] }
  pkg:      { mayDependOn: [] }       # pkg 不依赖任何 BC
```

### 跨 BC 协作的正确方式

| 方式 | 何时用 |
|------|------|
| 通过 API（gRPC / HTTP 内部调用） | 强一致或同步交互 |
| 通过事件（消息队列 / Outbox） | 最终一致或异步通知 |
| 把共享部分提到 `internal/pkg/` | **业务无关**的横切关注点 |

❌ **永远不要**：直接 import 对方的 model / repo / service。

**`cmd/<service>/main.go` 是唯一特权**：装配层可以同时 import 多个 BC 的构造函数来做依赖注入——这正是 BFF / 网关能存在的原因。

---

## Module 策略

### 选项 A：单 go.mod（**默认推荐**）

```
repo-root/
├── go.mod         # 唯一一个
├── go.sum
└── ...
```

**优点**：所有 import 用 `github.com/org/repo/...`，依赖一次到位，跨 BC refactor 容易，IDE / 工具链零配置。

**适合**：< 100 个服务、团队 < 50 人、服务发布节奏可对齐。

### 选项 B：多 go.mod + go.work（按需）

```
repo-root/
├── go.work
├── go.mod
├── tools/codegen/go.mod      # 独立 module（工具链）
└── pkg/client/go.mod         # 独立 module（对外发版）
```

**何时用**：有对外发布的库（`pkg/client`）需要独立版本号；`tools/` 要用激进依赖不影响主业务。

**禁止**：每个服务一个 go.mod（徒增复杂度）；混用 vendor 和 module。

---

## CODEOWNERS

每个 BC 一个 owner 团队：

```
# .github/CODEOWNERS

# 全局默认（兜底）
*                       @platform-team

# API 变更需要 API 委员会
/api/                   @api-committee @platform-team

# 各 Bounded Context
/internal/order/        @order-team
/internal/user/         @user-team
/internal/billing/      @billing-team

# 跨 BC 共享
/internal/pkg/          @platform-team
/internal/pkg/auth/     @security-team

# 数据库
/db/migrations/         @dba-team @platform-team

# 部署 / CI
/deploy/                @sre-team
/.github/               @platform-team

# 安全
/spec/11-security/      @security-team
```

**规则：**
- 每个目录都应被 CODEOWNERS 覆盖（兜底用 `*`）
- 跨 BC PR 自动要求多 owner review
- main 分支启用"required reviewers from CODEOWNERS"

---

## CI Affected Detection

改一行代码不应该跑全量测试。

### 方式 1：GitHub Actions paths 过滤

```yaml
on:
  pull_request:
    paths:
      - 'internal/order/**'
      - 'cmd/order-api/**'
      - 'cmd/order-worker/**'
      - 'api/order/**'
      - 'go.mod'

jobs:
  test-order:
    steps:
      - run: go test ./internal/order/... ./cmd/order-api/... ./cmd/order-worker/...
```

### 方式 2：基于 git diff 的脚本

```bash
# scripts/affected.sh
changed_dirs=$(git diff --name-only origin/main...HEAD | xargs -n1 dirname | sort -u)
affected_pkgs=$(go list ./... | xargs -I{} sh -c 'go list -deps {} | grep -qFf <(echo "$changed_dirs") && echo {}')
go test $affected_pkgs -race
```

### 方式 3：构建系统

Bazel / Buck2 / Pants 原生支持 affected。

### 必须缓存的资产

- Go build cache（`~/.cache/go-build`）
- Go module cache（`~/go/pkg/mod`）
- Docker layer 缓存
- 第三方工具下载（cosign、trivy、govulncheck）

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.24'
    cache: true
```

---

## 版本与发布

### 单版本（推荐）

整个 repo 一个版本号，所有镜像同 tag：

```bash
git tag v1.2.3
git push origin v1.2.3
# CI 构建 order-api:v1.2.3、order-worker:v1.2.3、user-api:v1.2.3
```

**优点**：原子、简单、易追溯。

### 独立版本（按服务）

```bash
git tag order-api/v1.2.3
git tag user-api/v0.5.1
```

需要 release pipeline 区分 tag prefix，按 prefix 构建对应 cmd。**何时用**：服务发布节奏完全不同（罕见）。

---

## 工具链统一

### 锁定工具版本

```
# .tool-versions（asdf / mise）
golang 1.24.0
protoc 25.1
golangci-lint 1.60.3
```

### Makefile 统一入口

所有构建 / 产物 / 部署目标必须由根 Makefile 作为**唯一入口**，CI / README / 本地开发统一调 `make <target>`。完整规范 + 最小模板见 [`08-delivery/makefile.md`](../08-delivery/makefile.md)。

新人 `git clone` + `make help` 即可上手。

---

## 第三方依赖策略

### vendor 与否

| 策略 | 优点 | 缺点 |
|------|------|------|
| **不 vendor**（推荐） | 仓库小，CI `go mod download` | 依赖 module proxy 可用 |
| **vendor** | air-gapped 友好、可审计 | 仓库大、PR diff 大 |

**红线**：选定一种，不要混用。

### Module proxy

```
GOPROXY=https://goproxy.example.com,https://proxy.golang.org,direct
GOSUMDB=sum.golang.org
GOPRIVATE=github.com/your-org/*
```

---

## 新增 BC / 新增 service 的标准流程

### 新增一个 Bounded Context

```
1. 在 internal/ 下创建新 BC：
   internal/<new-bc>/
   ├── server/  service/  biz/  data/  model/

2. 在 api/ 下定义 proto：
   api/<new-bc>/v1/<new-bc>.proto

3. 更新 CODEOWNERS：
   /internal/<new-bc>/   @<new-bc>-team
   /api/<new-bc>/        @<new-bc>-team

4. 写 ADR 说明 BC 拆分理由（02-architecture/architecture-decision-record.md）
```

### 新增一个 service（复用已有 BC）

```
1. 在 cmd/ 下创建入口：
   cmd/<bc>-<role>/main.go    # 命名：<bc>-api / <bc>-worker / <bc>-cli / <bc>-cron

2. 更新 deploy/：
   deploy/helm/<bc>-<role>/

3. 更新 Makefile：如果用了 `build-%` 模板（见 `08-delivery/makefile.md`），
   Makefile 会自动识别 `cmd/<bc>-<role>/`，无需改动；否则手动加 `build-<bc>-<role>` target

4. 走"新服务上线 Checklist"（high-level-design.md）
```

---

## 反模式

- ❌ `internal/<bc>/` 跨 BC 直接 import（必须通过 API / 事件 / `internal/pkg/`）
- ❌ 把 `<bc>` 切到"整个业务"那么大（`internal/ecommerce/`——等于没切）
- ❌ 把 `<bc>` 切到"一个功能"那么小（`internal/user_login/`——这是 biz 里的 method）
- ❌ 把所有代码都放 `pkg/`（`pkg/` 是对外的，绝大多数代码应在 `internal/`）
- ❌ `internal/pkg/` 变成大杂烩（只放**业务无关**的横切关注点）
- ❌ 一个 `cmd/main.go` 包含所有服务（每个服务独立 `cmd/<service>/`）
- ❌ `cmd/<service>/main.go` 里写业务逻辑（只做 wiring + signal）
- ❌ 共享数据库（每个 BC 拥有自己的表，不直接读对方表）
- ❌ 没有 CODEOWNERS（merge review 没强制 owner）
- ❌ 改一行触发全量 CI（必须做 affected detection）
- ❌ 一个服务一个 go.mod（除非有强理由）
- ❌ 服务直接读其他 BC 的 Redis / DB（违反边界）
- ❌ 工具版本不锁定（CI 与本地不一致）

## 自查

- [ ] 顶层布局符合 `api / cmd / internal / pkg / deploy / db / docs / spec` 标准
- [ ] `cmd/` 按 **service** 切，命名 `<bc>-<role>`
- [ ] `internal/` 按 **Bounded Context** 切
- [ ] 每个 BC 粒度合理（5k~30k LOC，独立团队可拥有，有自己的数据）
- [ ] 每个 BC 下有完整 `server/service/biz/data/model`
- [ ] `internal/<bc-A>/` 之间无直接 import（linter 验证）
- [ ] `internal/pkg/` 只放业务无关的横切关注点
- [ ] go.mod 策略已确定（默认单一）
- [ ] CODEOWNERS 全覆盖，每个 BC 有专门 owner
- [ ] CI 有 affected detection 或 path 过滤
- [ ] 工具版本锁定（`.tool-versions` 或类似）
- [ ] Makefile 提供统一入口（`make help` 列出全部）
- [ ] 第三方依赖策略一致（vendor 与否选定）
- [ ] 加新 BC / 新 service 有标准流程文档
- [ ] 跨 BC 协作走 API / 事件，不直接 import
