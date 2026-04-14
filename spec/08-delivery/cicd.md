# 08.2 - CI/CD Pipeline、Lint、Branch Protection

> 适用：配置 GitHub Actions、配 golangci-lint、配 pre-commit、配 main 分支保护规则。

## Pipeline 阶段全景

```
# PR 触发
lint → build → vet → test(-race) → coverage gate
     → govulncheck → gitleaks → trivy fs
     → build image → trivy image → sign image (cosign)
     → 生成 SBOM

# 合并 main 触发
上述 + 推送镜像 + 部署 staging

# tag 触发
cross-platform build → docker push → release notes → 部署生产（审批）
```

详细的镜像扫描 / 签名 / 多平台构建见 `release.md`。

## CI 配置示例

```yaml
# .github/workflows/go.yml
name: Go CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
          cache: true
      - uses: golangci/golangci-lint-action@v6
        with:
          version: v1.60.3

  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
          cache: true
      - run: go build ./...
      - run: go vet ./...
      - run: go test ./... -race -timeout 120s -coverprofile=coverage.out
      - name: Coverage gate
        run: |
          pct=$(go tool cover -func=coverage.out | grep total: | awk '{print $3}' | tr -d '%')
          echo "coverage: $pct%"
          awk -v p="$pct" 'BEGIN { if (p+0 < 70) exit 1 }'

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
      - name: govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
      - name: Trivy filesystem
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs
          severity: HIGH,CRITICAL
          exit-code: 1
          ignore-unfixed: true
```

## golangci-lint 配置

`.golangci.yml`（项目根目录）：

```yaml
run:
  timeout: 5m
  go: '1.24'

linters:
  disable-all: true
  enable:
    - govet
    - staticcheck
    - errcheck
    - gosimple
    - ineffassign
    - unused
    - gofmt
    - goimports
    - gocritic
    - gosec
    - revive
    - misspell
    - unconvert
    - unparam
    - bodyclose
    - noctx
    - rowserrcheck
    - sqlclosecheck
    - nilerr
    - prealloc

linters-settings:
  gosec:
    excludes:
      - G104  # 错误由 errcheck 覆盖
  revive:
    rules:
      - name: exported
      - name: var-naming
      - name: error-return
      - name: error-naming

issues:
  exclude-dirs:
    - vendor
    - docs/swagger
  max-same-issues: 0
```

## Pre-commit Hook

`.pre-commit-config.yaml`：

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: detect-private-key

  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-imports
      - id: go-vet
      - id: go-mod-tidy

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
```

安装：

```bash
pip install pre-commit
pre-commit install
```

## 合并门禁（Branch Protection）

main 分支必须启用：

- [ ] 必须通过所有 CI 检查（lint / build / test / security）
- [ ] 覆盖率不低于 70%（详见 `06-testing/README.md`）
- [ ] 至少 1 人 approve
- [ ] 禁止直接 push
- [ ] 禁止 force push
- [ ] 合并前必须 rebase / up-to-date with main
- [ ] 签名 commit（合规项目必需）

## 自查

- [ ] CI 包含 lint / build / test(-race) / 覆盖率门禁
- [ ] CI 包含 govulncheck / gitleaks / trivy
- [ ] golangci-lint 启用核心 linter
- [ ] pre-commit 已配置
- [ ] main 分支启用了 branch protection
