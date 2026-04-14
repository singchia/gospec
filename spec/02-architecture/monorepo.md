# 02.3 - Monorepo 仓库结构

> **适用**：初始化 monorepo、加新服务、决定 module 策略、配 CODEOWNERS、配 affected detection。
>
> 本规范基于 [Standard Go Project Layout](https://github.com/golang-standards/project-layout) 和 Google / Uber 等大厂 monorepo 实践。

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

## 标准目录布局

```
repo-root/
├── api/                    # Proto 定义（所有服务共享）
│   ├── v1/
│   │   ├── liaison.proto
│   │   └── billing.proto
│   ├── v2/
│   └── buf.yaml            # buf 工具配置
│
├── cmd/                    # 每个可执行入口
│   ├── manager/            # liaison-manager 服务
│   │   └── main.go
│   ├── worker/             # 后台 worker
│   │   └── main.go
│   └── cli/                # 命令行工具
│       └── main.go
│
├── internal/               # 仅本仓库使用，外部无法 import
│   ├── liaison/            # 业务领域 1
│   │   ├── controlplane/
│   │   ├── repo/
│   │   ├── model/
│   │   └── web/
│   ├── billing/            # 业务领域 2
│   │   └── ...
│   └── shared/             # 跨域共享（谨慎放）
│       ├── auth/           # 认证中间件
│       ├── tracing/        # OTel setup
│       ├── logging/        # slog 封装
│       └── lerrors/        # 通用错误类型
│
├── pkg/                    # 对外公开的库（可选）
│   └── client/             # 给外部用户的 SDK
│
├── deploy/                 # 部署配置
│   ├── docker-compose.yml
│   ├── helm/
│   │   ├── liaison/
│   │   └── billing/
│   └── k8s/
│
├── db/                     # 数据库 migration（13-database-migration/）
│   └── migrations/
│
├── scripts/                # 构建 / 工具脚本
│   ├── proto-gen.sh
│   └── lint.sh
│
├── tools/                  # 内部工具的源码（独立 module）
│   ├── codegen/
│   └── mock-server/
│
├── docs/                   # 跨服务文档（spec/09 定义）
│   ├── requirements/
│   ├── adr/
│   ├── design/
│   ├── runbooks/
│   ├── postmortems/
│   ├── slo/
│   └── security/
│
├── test/                   # 跨服务集成测试 / E2E
│   └── e2e/
│
├── third_party/            # 必须 vendor 的第三方代码
│
├── spec/                   # 项目规范（本目录）
│
├── go.mod
├── go.sum
├── go.work                 # 仅多 module 项目
├── Makefile
├── CODEOWNERS              # 或 .github/CODEOWNERS
├── .github/
│   └── workflows/
├── .golangci.yml
├── .tool-versions          # asdf / mise 工具链锁定
└── README.md
```

## 关键目录规则

| 目录 | 职责 | 谁可以 import |
|------|------|--------------|
| `api/` | Proto + 生成代码 | 所有 |
| `cmd/<name>/` | 可执行入口 | 不被 import |
| `internal/<domain>/` | 业务领域代码 | 仅本 domain + cmd |
| `internal/shared/` | 跨域共享 | 任何 internal |
| `pkg/` | 对外公开的库 | 任何项目（包括外部） |
| `tools/` | 内部工具 | 不被业务代码 import |
| `third_party/` | vendored 第三方 | 不被业务代码直接 import，封装后用 |

**关键：**
- `internal/` 是 Go 编译器原生强制的边界——`internal/foo/...` 只能被 `internal/foo/` 的兄弟和父级 import
- `pkg/` 应该非常小心，里面的东西一旦发布就是 API 承诺
- 大多数代码都应该在 `internal/` 而非 `pkg/`

---

## Domain 边界

### 红线

`internal/billing/` **禁止** import `internal/liaison/`，反之亦然。

```go
// ❌ 跨 domain 直接 import
package billing

import "github.com/org/repo/internal/liaison/model"  // 禁止
```

### 强制方式

1. **Code Review**：CODEOWNERS 强制双 owner review
2. **Linter**：用 `import-boundaries` / `go-arch-lint` / 自定义脚本检查
3. **CI 阻断**：linter 失败阻断 PR

```yaml
# .go-arch-lint.yml 示例
version: 3
workdir: .
allow:
  depOnAnyVendor: true
components:
  liaison:
    in: internal/liaison/**
  billing:
    in: internal/billing/**
  shared:
    in: internal/shared/**
deps:
  liaison:
    mayDependOn: [shared]
  billing:
    mayDependOn: [shared]
  shared:
    mayDependOn: []  # shared 不依赖任何 domain
```

### 跨 domain 协作的正确方式

| 方式 | 何时用 |
|------|------|
| 通过 API（gRPC / HTTP 内部调用） | 强一致或同步交互 |
| 通过事件（消息队列 / Outbox） | 最终一致或异步通知 |
| 把共享部分提到 `internal/shared/` | 业务无关的横切关注点 |

❌ **永远不要**：直接 import 对方的 model / repo / service。

---

## Module 策略

### 选项 A：单 go.mod（推荐起步）

```
repo-root/
├── go.mod         # 唯一一个
├── go.sum
└── ...
```

**优点：**
- 简单：所有 import 用 `github.com/org/repo/...`
- 升级依赖一次到位
- 跨 domain refactor 容易
- IDE / 工具链零配置

**缺点：**
- 服务越多，编译图越大
- 一个依赖升级影响所有服务

**适合：**
- < 100 个服务
- 团队 < 50 人
- 服务发布节奏可对齐

### 选项 B：多 go.mod + go.work（按需）

```
repo-root/
├── go.work         # 工作区
├── go.mod          # 主 module
├── tools/codegen/
│   └── go.mod      # 独立 module
└── pkg/client/
    └── go.mod      # 独立 module（对外发版）
```

```go
// go.work
go 1.24

use (
    .
    ./tools/codegen
    ./pkg/client
)
```

**优点：**
- 库可独立版本号发布
- 工具链与主业务隔离（codegen 可以用更激进的依赖）
- 服务发布节奏可独立

**缺点：**
- 复杂：每个 module 一份 go.sum
- 跨 module refactor 难
- IDE 配置成本高

**适合：**
- 有对外发布的库（pkg/client）
- 服务发布节奏完全独立
- 工具链需要独立依赖

### 推荐策略

**默认单 go.mod**。只在以下情况下拆 module：
- `pkg/client` 等需要独立版本号的对外库
- `tools/` 下的工具想用激进依赖（不影响主业务）

**禁止：**
- 一个服务一个 go.mod（除非有强理由）
- 混用 vendor 和 module（选一种）

---

## CODEOWNERS

```
# .github/CODEOWNERS

# 全局默认（兜底）
*                       @platform-team

# API 变更需要 API 委员会
/api/                   @api-committee @platform-team

# 各业务领域
/internal/liaison/      @liaison-team
/internal/billing/      @billing-team
/internal/shared/       @platform-team
/internal/shared/auth/  @security-team

# 数据库
/db/migrations/         @dba-team @platform-team

# 部署相关
/deploy/                @sre-team
/.github/               @platform-team

# 安全相关
/spec/11-security/      @security-team
/scripts/security/      @security-team

# 文档
/docs/                  @platform-team
/spec/                  @platform-team
```

**规则：**
- 每个目录都应被 CODEOWNERS 覆盖（兜底用 `*`）
- 跨 domain PR 自动要求多 owner review
- 安全 / API / DB 变更必须有专门 owner
- main 分支启用"required reviewers from CODEOWNERS"（`08-delivery/cicd.md` 的 branch protection）

---

## CI Affected Detection

改一行代码不应该跑全量测试。

### 方式 1：GitHub Actions paths 过滤

```yaml
on:
  pull_request:
    paths:
      - 'internal/liaison/**'
      - 'cmd/manager/**'
      - 'api/v1/liaison.proto'
      - 'go.mod'

jobs:
  test-liaison:
    steps:
      - run: go test ./internal/liaison/... ./cmd/manager/...
```

### 方式 2：基于 git diff 的脚本

```bash
# scripts/affected.sh
changed_dirs=$(git diff --name-only origin/main...HEAD | xargs -n1 dirname | sort -u)
affected_pkgs=$(go list ./... | xargs -I{} sh -c 'go list -deps {} | grep -qFf <(echo "$changed_dirs") && echo {}')
go test $affected_pkgs -race
```

### 方式 3：构建系统

- **Bazel**：原生支持 affected
- **Buck2 / Pants**：同上
- **Mage / Task**：用脚本封装

### 必须缓存的资产

- Go build cache（`~/.cache/go-build`）
- Go module cache（`~/go/pkg/mod`）
- Docker layer 缓存
- 第三方工具下载（cosign、trivy、govulncheck）

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.24'
    cache: true   # 自动缓存 go-build 和 mod cache
```

---

## 版本与发布

### 单版本（推荐）

整个 repo 一个版本号，所有镜像同 tag：

```bash
git tag v1.2.3
git push origin v1.2.3
# CI 构建 manager:v1.2.3、worker:v1.2.3、cli:v1.2.3
```

**优点**：原子、简单、易追溯。

### 独立版本（按服务）

```bash
git tag liaison/v1.2.3
git tag billing/v0.5.1
```

需要 release pipeline 区分 tag prefix，按 prefix 构建对应 cmd。

**何时用**：服务的发布节奏完全不同（罕见）。

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

```makefile
.PHONY: build test lint proto migrate help

build:
	go build ./cmd/...

test:
	go test ./... -race -timeout 120s

lint:
	golangci-lint run ./...

proto:
	./scripts/proto-gen.sh

migrate:
	migrate -path db/migrations -database "$$DSN" up

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
```

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
# 公司内推荐自建 proxy + checksum
GOPROXY=https://goproxy.example.com,https://proxy.golang.org,direct
GOSUMDB=sum.golang.org
GOPRIVATE=github.com/your-org/*
```

---

## 加新服务的标准流程

```
1. 在 internal/ 下创建新 domain：
   internal/newservice/
   ├── controlplane/
   ├── repo/
   ├── model/
   └── web/

2. 在 cmd/ 下创建入口：
   cmd/newservice/main.go

3. 在 api/v1/ 下定义 proto：
   api/v1/newservice.proto

4. 更新 CODEOWNERS：
   /internal/newservice/  @newservice-team

5. 更新 deploy/：
   deploy/helm/newservice/

6. 更新 Makefile：
   build-newservice:
       go build -o bin/newservice ./cmd/newservice

7. 走"新服务上线 Checklist"（`high-level-design.md`）
```

---

## 反模式

- ❌ 把所有代码都放 `pkg/`（pkg 是对外的，绝大多数代码应在 `internal/`）
- ❌ 跨 domain 直接 import（必须通过 API / 事件 / shared）
- ❌ 一个 `cmd/main.go` 包含所有服务（每个服务独立 `cmd/<name>/`）
- ❌ 共享数据库（每个服务的数据自己拥有，不直接读对方表）
- ❌ 没有 CODEOWNERS（merge review 没强制 owner）
- ❌ 改一行触发全量 CI（必须做 affected detection）
- ❌ `internal/shared/` 变成大杂烩（业务无关、接口稳定的才能进）
- ❌ 一个服务一个 go.mod（除非有强理由，徒增复杂度）
- ❌ 服务直接读其他服务的 Redis / DB（违反边界）
- ❌ 工具版本不锁定（CI 与本地不一致）

## 自查

- [ ] 目录布局符合 `cmd / internal / pkg / api / deploy / docs / spec` 标准
- [ ] `internal/<domain>/` 之间无直接 import（linter 验证）
- [ ] go.mod 策略已确定（默认单一）
- [ ] CODEOWNERS 全覆盖，关键目录有专门 owner
- [ ] CI 有 affected detection 或 path 过滤
- [ ] 工具版本锁定（`.tool-versions` 或类似）
- [ ] Makefile 提供统一入口（`make help` 列出全部）
- [ ] 第三方依赖策略一致（vendor 与否选定）
- [ ] 加新服务有标准流程文档
- [ ] 跨 domain 协作走 API / 事件，不直接 import
