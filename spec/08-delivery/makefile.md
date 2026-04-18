# 08.4 - Makefile：统一构建 / 产物 / 部署入口

> **适用**：写 / 改根 `Makefile`、加新构建目标、配 CI / Dockerfile / README 的构建命令、加新服务时新增 target。

## 红线（不可违反）

**所有构建 / 产物 / 部署目标必须由根 Makefile 作为唯一入口。**

- ✅ CI / GitHub Actions step 只调 `make <target>`
- ✅ README / AGENTS.md / 新人 onboarding 只列 `make <target>`
- ✅ Dockerfile 的多阶段构建内部可以 `go build`（那是 docker build 的上下文），但**项目级的 image 构建入口必须是 `make image`**
- ✅ 开发者本地、CI、生产构建**用同一个 make target**
- ❌ CI workflow 里直接写 `go build ./...` / `docker build -t ...` / `kubectl apply -f ...`
- ❌ README 里写 "`go run cmd/xxx/main.go`"
- ❌ 散落多个 Makefile 在子目录做构建（仅允许一个根 Makefile，可 `include` 拆分）
- ❌ 硬编码版本号 / 镜像 tag / 注册中心地址（必须用变量，从 git / 环境注入）

**动机**：本地 / CI / 生产三处用不同命令构建是经典故障源头——本地过 CI 挂，CI 过生产挂。Makefile 是契约：**一个命令一个结果，所有人一致**。

---

## 必备目标（mandatory）

每个项目的 Makefile **必须**提供以下 target。缺一个视为 spec 违反。

### 元信息 / 入口

| Target | 职责 |
|--------|------|
| `help` | 默认 target，打印所有可用 target + 注释 |
| `tools` | 安装 / 检查所有构建依赖工具（protoc / golangci-lint / buf / cosign / helm / goose / swag 等） |

### 代码生成 / API

| Target | 职责 |
|--------|------|
| `proto` 或 `api` | 从 `api/**/*.proto` 生成 Go 代码（gRPC / HTTP / OpenAPI） |
| `mock` | 从接口生成 mock（mockery / gomock），可选 |
| `wire` | DI 代码生成（google/wire），可选 |
| `swag` | Swagger 文档生成 |

### 质量门禁

| Target | 职责 |
|--------|------|
| `fmt` | `gofmt -w` + `goimports -w` |
| `vet` | `go vet ./...` |
| `lint` | `golangci-lint run ./...` |
| `test` | `go test ./... -race` 默认单元测试 |
| `test-unit` | 仅单元测试（不要求外部依赖） |
| `test-integration` | 集成测试（testcontainers 起容器） |
| `test-e2e` | E2E 测试（连真实部署环境） |
| `cover` | 跑测试 + 输出覆盖率报告 |

### 构建

| Target | 职责 |
|--------|------|
| `build` | 构建所有 service（遍历 `cmd/*`） |
| `build-<service>` | 构建单个 service（如 `build-order-api`） |
| `build-cross` | 多平台构建（linux/amd64 + linux/arm64 + darwin/arm64），发版用 |

### 镜像

| Target | 职责 |
|--------|------|
| `image` | 构建所有 service 的 Docker 镜像 |
| `image-<service>` | 构建单个 service 的镜像 |
| `image-push` | 推送所有镜像到 registry |
| `image-sign` | cosign 签名（发版流程） |

### 数据 / migration

| Target | 职责 |
|--------|------|
| `migrate-up` | 应用所有未执行的 migration |
| `migrate-down` | 回滚一个 migration |
| `migrate-status` | 显示 migration 状态 |
| `migrate-new name=xxx` | 新建 migration 文件 |

### 部署

| Target | 职责 |
|--------|------|
| `deploy-<env>` | 部署到指定环境（`dev` / `staging` / `prod`），封装 helm / kubectl / terraform |
| `rollback-<env>` | 回滚指定环境 |

### 运行 / 清理

| Target | 职责 |
|--------|------|
| `run-<service>` | 本地起服务（方便开发） |
| `compose-up` / `compose-down` | 本地 docker-compose 起 / 停依赖（MySQL / Redis / Kafka 等） |
| `clean` | 清理 `bin/` / `dist/` / 生成的 swagger / mock |

### 发版

| Target | 职责 |
|--------|------|
| `release` | 打 tag + 推送（触发 CI 发版流水线），禁止本地构建+推生产 |

---

## 命名规范

- 所有 target **kebab-case**：`build-order-api`、`migrate-up`、`test-integration`
- 动词开头：`build-*` / `test-*` / `image-*` / `deploy-*` / `migrate-*`
- per-service / per-env target 用 **prefix-<name>** 格式，`name` 和 `cmd/<service>/` / 部署环境名一致
- 所有 target 必须 `.PHONY`（除非真的是文件 target）

---

## 自文档 help（强制）

`make help` 是默认 target，通过 target 行后的 `##` 注释自动生成帮助。

```makefile
.DEFAULT_GOAL := help

help:  ## 列出所有 target
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'
```

**规则：**
- 每个对外 target 必须有 `## 简要描述`
- 内部辅助 target（如 `_check-docker`）不加 `##`，不出现在 help 里
- `make` 裸命令等同 `make help`

---

## 版本 / 元信息注入

构建必须把 git 元信息注入二进制，发布时可追溯：

```makefile
# 版本信息（优先从环境 VERSION，否则从 git）
VERSION        ?= $(shell git describe --tags --always --dirty)
GIT_COMMIT     := $(shell git rev-parse --short HEAD)
BUILD_TIME     := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

# 镜像
IMAGE_REGISTRY ?= ghcr.io/your-org
IMAGE_REPO     ?= your-repo

# ldflags：去调试信息 + 注入版本
LDFLAGS := -s -w \
	-X main.Version=$(VERSION) \
	-X main.GitCommit=$(GIT_COMMIT) \
	-X main.BuildTime=$(BUILD_TIME)

GOFLAGS := -trimpath -ldflags="$(LDFLAGS)"
```

**红线：**
- ❌ 在 Makefile 里硬编码 `VERSION := v1.2.3`
- ❌ 镜像 tag 用 `latest` 进生产
- ✅ 服务启动时打印 `Version / GitCommit / BuildTime`（便于运维排查）

---

## per-service 目标模板

在 monorepo 里遍历 `cmd/*` 自动生成 per-service target：

```makefile
SERVICES := $(notdir $(wildcard cmd/*))

# build-<service>
build: $(addprefix build-,$(SERVICES))  ## 构建所有 service

build-%: ## 构建单个 service（如 make build-order-api）
	@echo ">>> building $*"
	@go build $(GOFLAGS) -o bin/$* ./cmd/$*

# image-<service>
image: $(addprefix image-,$(SERVICES))  ## 构建所有镜像

image-%: ## 构建单个镜像
	@echo ">>> building image $*"
	@docker build \
		--build-arg SERVICE=$* \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE_REGISTRY)/$(IMAGE_REPO)/$*:$(VERSION) \
		.

# run-<service>：本地开发起服务
run-%: ## 本地运行单个 service
	@go run ./cmd/$*
```

这样**新增一个 service 只要在 `cmd/` 下创建目录**，Makefile 自动识别，`make build-new-service` 立刻可用，无需改 Makefile。

---

## Shell / 可移植性

```makefile
# 严格模式：任何一步失败立即退出；pipefail 保证管道中间失败也退出
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -e -c

# 禁用隐式规则（加快解析 + 避免意外匹配）
MAKEFLAGS += --no-builtin-rules
```

**兼容 macOS + Linux：**
- 禁止用 GNU-only 特性：`readlink -f`（macOS 没有）、`date --iso-8601`（macOS 不支持）
- 日期格式化用 `date -u +%Y-%m-%dT%H:%M:%SZ`
- 路径用 `$(CURDIR)` 而非 `$(shell pwd)`
- 多行命令用 `\` + `&&`，或在独立 shell 脚本里写复杂逻辑（脚本放 `scripts/`）

---

## 工具版本锁定

`tools` target 必须安装锁定版本的工具，避免"本地能跑 CI 跑不起来"：

```makefile
tools: ## 安装 / 检查构建工具
	@command -v protoc >/dev/null || { echo "❌ protoc 未安装，参见 .tool-versions"; exit 1; }
	@command -v buf >/dev/null || go install github.com/bufbuild/buf/cmd/buf@v1.35.0
	@command -v golangci-lint >/dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.60.3
	@command -v mockery >/dev/null || go install github.com/vektra/mockery/v2@v2.43.2
	@command -v goose >/dev/null || go install github.com/pressly/goose/v3/cmd/goose@v3.21.1
	@command -v swag >/dev/null || go install github.com/swaggo/swag/cmd/swag@v1.16.3
```

**协作：**
- 语言级工具链（Go / protoc 版本）由 `.tool-versions`（asdf / mise）锁定
- 由 Go 管理的 CLI 工具（buf / golangci-lint 等）写死版本号，不用 `@latest`
- CI 第一步调 `make tools`，保证所有工具就位

---

## CI 只调 make（强制）

```yaml
# .github/workflows/go.yml
jobs:
  build-test:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.24', cache: true }
      - run: make tools
      - run: make lint
      - run: make test
      - run: make build
      - run: make image
```

**红线：**
- ❌ CI step 里写 `go build ./...` —— 必须 `make build`
- ❌ CI step 里写 `docker build ...` —— 必须 `make image`
- ❌ CI step 里装工具用临时 `go install` —— 必须 `make tools`

详见 `cicd.md` 和 `release.md`。

---

## Deploy target 模板

部署同样要走 Makefile，禁止在 CI 里直接 `kubectl` / `helm` / `terraform`：

```makefile
NAMESPACE ?= default
KUBECTX   ?= $(error KUBECTX 必须显式指定，如 make deploy-staging KUBECTX=staging-cluster)

deploy-dev: ## 部署到 dev 环境
	@KUBECTX=dev-cluster ENV=dev $(MAKE) _deploy

deploy-staging: ## 部署到 staging 环境
	@KUBECTX=staging-cluster ENV=staging $(MAKE) _deploy

deploy-prod: ## 部署到生产（需 DEPLOY_APPROVED=yes）
	@test "$(DEPLOY_APPROVED)" = "yes" || { echo "❌ 生产部署需要 DEPLOY_APPROVED=yes"; exit 1; }
	@KUBECTX=prod-cluster ENV=prod $(MAKE) _deploy

_deploy:  # 内部 target，不进 help
	@helm upgrade --install $(IMAGE_REPO) deploy/helm/$(IMAGE_REPO) \
		--namespace $(NAMESPACE) \
		--kube-context $(KUBECTX) \
		--set image.tag=$(VERSION) \
		--set env=$(ENV) \
		--wait --timeout 5m

rollback-%: ## 回滚指定环境
	@helm rollback $(IMAGE_REPO) --kube-context $*-cluster
```

**生产部署红线：**
- 生产 deploy target 必须检查额外 flag（`DEPLOY_APPROVED=yes`），防止手滑
- 生产部署必须在 GitHub Environments 审批流后由 CI 调用（不应本地跑）
- 回滚是**必备 target**，灾难时能一条命令回

---

## 最小可用模板

给新项目起步用——粘贴即用，按项目改变量：

```makefile
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -e -c
MAKEFLAGS += --no-builtin-rules

VERSION        ?= $(shell git describe --tags --always --dirty)
GIT_COMMIT     := $(shell git rev-parse --short HEAD)
BUILD_TIME     := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
IMAGE_REGISTRY ?= ghcr.io/your-org
IMAGE_REPO     ?= your-repo
SERVICES       := $(notdir $(wildcard cmd/*))

LDFLAGS := -s -w -X main.Version=$(VERSION) -X main.GitCommit=$(GIT_COMMIT) -X main.BuildTime=$(BUILD_TIME)
GOFLAGS := -trimpath -ldflags="$(LDFLAGS)"

.DEFAULT_GOAL := help
.PHONY: help tools proto fmt vet lint test test-unit test-integration test-e2e cover \
        build build-cross image image-push image-sign \
        migrate-up migrate-down migrate-status \
        compose-up compose-down clean release

help: ## 列出所有 target
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

tools: ## 安装构建工具
	@command -v buf >/dev/null || go install github.com/bufbuild/buf/cmd/buf@v1.35.0
	@command -v golangci-lint >/dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.60.3

proto: ## 生成 proto 代码
	@buf generate

fmt: ## 格式化代码
	@gofmt -w . && goimports -w .

vet: ## go vet
	@go vet ./...

lint: ## 运行 golangci-lint
	@golangci-lint run ./...

test: test-unit ## 默认跑单元测试

test-unit: ## 单元测试
	@go test ./... -race -timeout 120s

test-integration: ## 集成测试
	@go test ./... -tags=integration -race -timeout 300s

cover: ## 生成覆盖率报告
	@go test ./... -race -coverprofile=coverage.out
	@go tool cover -html=coverage.out -o coverage.html

build: $(addprefix build-,$(SERVICES)) ## 构建所有 service
build-%: ## 构建单个 service
	@go build $(GOFLAGS) -o bin/$* ./cmd/$*

image: $(addprefix image-,$(SERVICES)) ## 构建所有镜像
image-%: ## 构建单个镜像
	@docker build --build-arg SERVICE=$* --build-arg VERSION=$(VERSION) \
		-t $(IMAGE_REGISTRY)/$(IMAGE_REPO)/$*:$(VERSION) .

image-push: ## 推送所有镜像
	@for s in $(SERVICES); do docker push $(IMAGE_REGISTRY)/$(IMAGE_REPO)/$$s:$(VERSION); done

migrate-up: ## 应用 migration
	@goose -dir db/migrations $(DB_DRIVER) "$(DB_DSN)" up

migrate-down: ## 回滚一个 migration
	@goose -dir db/migrations $(DB_DRIVER) "$(DB_DSN)" down

migrate-status: ## migration 状态
	@goose -dir db/migrations $(DB_DRIVER) "$(DB_DSN)" status

compose-up: ## 起本地依赖（MySQL / Redis 等）
	@docker-compose up -d

compose-down: ## 停本地依赖
	@docker-compose down

run-%: ## 本地运行 service
	@go run ./cmd/$*

clean: ## 清理产物
	@rm -rf bin/ dist/ coverage.out coverage.html

release: ## 打 tag 触发发版 CI（make release VERSION=v1.2.3）
	@test -n "$(VERSION)" || { echo "❌ 指定 VERSION"; exit 1; }
	@git tag -a $(VERSION) -m "Release $(VERSION)"
	@git push origin $(VERSION)
```

---

## 反模式

- ❌ Makefile 里 `go build cmd/some-service/main.go`（路径硬编码——加服务就忘了改 Makefile）
- ❌ 用 `@latest` 安装工具（CI 和本地可能装到不同版本）
- ❌ 把复杂逻辑写在 Makefile recipe 里（超过 5 行就拆到 `scripts/xxx.sh`）
- ❌ target 之间通过 `cd` 切目录不加 `&&`（单独一行的 `cd` 下一条命令又回到根目录）
- ❌ 没有 `.PHONY` 声明（当目录里恰好有同名文件时 target 变成"已存在"不执行）
- ❌ 多个 Makefile 散在子目录做构建（难维护；如果要拆用 `include Makefile.xxx`）
- ❌ `deploy-prod` 没有审批保护（误操作直击生产）
- ❌ `image` target 漏了 `VERSION` 变量注入（镜像 tag 永远是 `latest`）
- ❌ CI 绕过 Makefile 直接跑 `go test`（本地 CI 不一致，失败难复现）

## 自查

- [ ] 存在根 Makefile，且是**唯一**的 Makefile（或通过 `include` 拆分）
- [ ] `make help` 列出所有对外 target 和说明
- [ ] 每个对外 target 都有 `## 注释`
- [ ] 所有非文件 target 都 `.PHONY`
- [ ] 必备 target 齐备：`help` / `tools` / `proto` / `build` / `image` / `test` / `lint` / `migrate-up` / `deploy-*` / `clean`
- [ ] per-service / per-env target 用模板生成（`build-%`、`deploy-%`）
- [ ] 版本 / commit / build-time 注入二进制和镜像 tag
- [ ] 生产部署 target 有审批保护（`DEPLOY_APPROVED=yes` 或类似）
- [ ] CI 脚本只调 `make <target>`，无直接 `go build` / `docker build` / `kubectl`
- [ ] README 的"本地起步"小节只列 `make <target>`
- [ ] Shell 严格模式（`-o pipefail -e`）
- [ ] 兼容 macOS + Linux，不用 GNU-only 标志
- [ ] 工具版本锁定（不用 `@latest`），`make tools` 一键装齐
- [ ] Makefile 变更通过 CI（修 Makefile 的 PR 会自动跑 `make lint` / `make test` / `make build`）
