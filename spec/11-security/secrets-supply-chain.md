# 11.3 - 密钥、依赖与容器安全

> 适用：使用密钥/凭证、引入第三方依赖、写 Dockerfile/K8s manifest。

## 密钥管理

### 红线

- ❌ 密钥不进代码仓库（包括测试代码、注释、`.env`）
- ❌ 密钥不打进 Docker 镜像
- ❌ 密钥不进日志
- ❌ 密钥不放在环境变量明文（CI 除外，且必须 mask）

### 推荐方案

| 场景 | 方案 |
|------|------|
| 本地开发 | `.env.local` + `.gitignore` |
| CI/CD | GitHub Actions Secrets / Vault |
| 生产环境 | HashiCorp Vault / AWS Secrets Manager / K8s Secrets（启用加密） |
| 数据库密码 | 短期凭证（动态生成） |

### 密钥轮转

- TLS 证书：自动续期（cert-manager / Let's Encrypt）
- API Key：定期轮转（建议 ≤ 90 天）
- JWT 签名密钥：支持多 key 并存以平滑切换

### 提交前扫描

```bash
gitleaks detect --source . --verbose
trufflehog filesystem .

# pre-commit hook
pre-commit install
```

---

## 依赖与供应链

### 漏洞扫描（必须接入 CI）

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...

trivy fs --scanners vuln,license .
```

### 依赖引入审查

新引入第三方包必须评估：

- [ ] 维护活跃度（最近半年有提交）
- [ ] Star / 下载量
- [ ] 是否有已知 CVE
- [ ] License 兼容（避免 GPL/AGPL 进入闭源代码）
- [ ] 是否真的需要（标准库能否实现）

### 自动化升级

- `Dependabot` / `Renovate` 每周扫描
- 安全补丁自动 PR，业务依赖人工 review

### SBOM 与镜像签名

```bash
syft packages dir:. -o cyclonedx-json > sbom.json
cosign sign --key cosign.key registry/app:v1.0.0
cosign verify --key cosign.pub registry/app:v1.0.0
```

CI 集成示例见 `08-delivery/cicd.md`。

---

## 容器与运行时

### Dockerfile 最小化

```dockerfile
# ✅ 多阶段 + distroless
FROM golang:1.24 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/manager

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

### 镜像扫描

```bash
trivy image registry/app:v1.0.0 --severity HIGH,CRITICAL --exit-code 1
```

### 容器红线

- ❌ 禁止 `root` 用户运行
- ❌ 禁止挂载 `docker.sock`
- ❌ 禁止 `--privileged`
- ❌ 镜像不包含 shell、curl、wget（除非必要）
- ✅ 启用 read-only 文件系统
- ✅ 设置 CPU / 内存 limits
- ✅ Drop 所有 capabilities，只保留必要的

### K8s SecurityContext

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

## 自查

- [ ] 无密钥进入代码 / 镜像 / 日志
- [ ] 新依赖通过 `govulncheck`，license 兼容
- [ ] Dockerfile 多阶段 + distroless / 非 root
- [ ] 镜像通过 trivy 扫描，无 HIGH/CRITICAL
- [ ] K8s manifest 设置 securityContext
