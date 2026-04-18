# 08.3 - 发版、多平台构建、镜像签名、生产审批

> 适用：打 tag 发版、构建多平台二进制、推送镜像、签名、生产部署审批。

## Release 工作流

```
版本 tag → CI 构建 → 多平台二进制 → 镜像构建 → 镜像扫描 → 镜像签名 → SBOM → Release Notes → 部署
```

1. 确认 main 分支所有 CI 通过
2. 打 tag：`git tag v1.x.x && git push origin v1.x.x`
3. GitHub Actions 自动触发：多平台构建 / 镜像 / 签名 / SBOM
4. GitHub Releases 自动发布 Release Notes
5. 部署生产（走审批，详见下文）

## 多平台构建

多平台构建必须封装为 Makefile target（`build-cross`），详见 `makefile.md`。示例：

```makefile
build-cross: ## 多平台构建（发版用）
	@for os in linux darwin; do \
	  for arch in amd64 arm64; do \
	    for svc in $(SERVICES); do \
	      GOOS=$$os GOARCH=$$arch go build -trimpath -ldflags="$(LDFLAGS)" \
	        -o dist/$$svc-$$os-$$arch ./cmd/$$svc; \
	    done; \
	  done; \
	done
```

`-trimpath` 去除编译路径，`-s -w` 去除调试信息和符号表，减小体积。

**红线**：CI / 本地都调 `make build-cross`，不在 CI YAML 里重写 `go build` 命令。

## 发布流水线

```yaml
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write  # cosign keyless signing
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.24', cache: true }

      - run: make tools
      - run: make build-cross                    # 多平台二进制
      - run: make image IMAGE_TAG=${GITHUB_REF_NAME}
      - run: make image-push IMAGE_TAG=${GITHUB_REF_NAME}

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: $REGISTRY/$IMAGE:${GITHUB_REF_NAME}
          format: cyclonedx-json

      - name: Scan image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: $REGISTRY/$IMAGE:${GITHUB_REF_NAME}
          severity: HIGH,CRITICAL
          exit-code: 1

      - run: make image-sign IMAGE_TAG=${GITHUB_REF_NAME}

      - name: Release notes
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

> 所有构建 / 推送 / 签名步骤都走 Makefile target（`build-cross` / `image` / `image-push` / `image-sign`）。CI YAML 不含任何 `go build` / `docker buildx` / `cosign sign` 的直接命令。详见 `makefile.md`。

容器最佳实践 / Dockerfile 模板见 `11-security/secrets-supply-chain.md`。

## 生产部署审批

生产部署走 [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments) 审批：

```yaml
  deploy-prod:
    needs: release
    runs-on: ubuntu-latest
    environment:
      name: production    # 在 repo settings 配置 required reviewers
      url: https://app.example.com
    steps:
      - name: Deploy
        run: ./scripts/deploy.sh prod ${{ github.ref_name }}
```

部署策略 / 灰度 / 回滚详见 `12-operations/deployment.md`。

## 自查

- [ ] tag 命名符合 SemVer
- [ ] 镜像通过 trivy 扫描，无 HIGH/CRITICAL
- [ ] 镜像已用 cosign 签名
- [ ] SBOM 已生成并归档
- [ ] Release Notes 自动生成
- [ ] 生产部署有 reviewer 审批
- [ ] 有明确回滚步骤（详见 `12-operations/deployment.md`）
