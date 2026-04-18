# 08 - 交付

> 从代码提交到上线发布的全流程。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 写 commit、起分支、走开发工作流、本地跑起来 | `git.md` |
| 写 / 改 Makefile、加构建 / 镜像 / 部署 target | `makefile.md` |
| 配 CI pipeline、golangci-lint、pre-commit、覆盖率门禁、分支保护 | `cicd.md` |
| 发版 / 多平台构建 / 镜像签名 / SBOM / 生产部署审批 | `release.md` |

## 核心原则（全局）

1. **原子提交**：每个 commit 只做一件事，可独立回滚
2. **每个 commit 可构建**：`go build ./...` 和 `go test ./...` 必须通过
3. **CI 是真理**：本地通过不算，CI 通过才算
4. **发布是过程不是动作**：lint → test → scan → sign → 灰度 → 全量

## 强制约束（不可违反）

- 提交格式：`<type>(<scope>): <desc>`
- 禁止提交敏感信息（密码、密钥、token）
- 禁止 force push main/master
- main 分支必须启用 branch protection
- CI 必须启用 `-race`
- 安全扫描（govulncheck、gitleaks、trivy）必须在 CI 阻断 HIGH/CRITICAL（详见 `11-security/secrets-supply-chain.md`）
- **所有构建 / 产物 / 部署目标必须由根 Makefile 作为唯一入口**：CI / README / 本地开发统一调 `make <target>`，禁止直接 `go build` / `docker build` / `kubectl apply`（详见 `makefile.md`）
