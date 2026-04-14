# 06.3 - Fuzz、Benchmark、安全测试

> **适用**：写 fuzz testing、写 benchmark、跑性能回归对比、跑安全静态扫描。

## Fuzz 测试

Go 1.18+ 原生支持。**对解析器、协议处理、用户输入校验、加密函数强烈推荐**。

```go
func FuzzParseEdgeName(f *testing.F) {
    // seed corpus
    f.Add("normal-name")
    f.Add("")
    f.Add("a/b/c")
    f.Add("../../../etc/passwd")

    f.Fuzz(func(t *testing.T, name string) {
        result, err := parseEdgeName(name)
        if err != nil { return } // 拒绝非法输入是正常的

        // 不变式：成功解析的结果必须能再次序列化回原值
        if got := result.String(); got != name {
            t.Errorf("roundtrip: %q -> %q", name, got)
        }
    })
}
```

运行：

```bash
# 持续跑 30 秒
go test -fuzz=FuzzParseEdgeName -fuzztime=30s ./pkg/edge

# CI 中限时跑 5 分钟
go test -fuzz=FuzzParseEdgeName -fuzztime=5m ./pkg/edge
```

**找到 crash 后**：crash input 会自动保存到 `testdata/fuzz/<FuzzName>/`，作为新的 seed corpus 加入回归测试。

**何时不需要 fuzz**：
- 纯 CRUD 业务逻辑
- 输入空间小且明确（用表格驱动覆盖更高效）

CI 策略：每次 PR 跑短时（30s-1min），每日定时跑长时（30min+）。

---

## Benchmark

热点函数（请求处理、序列化、加密、查询）必须有 benchmark：

```go
func BenchmarkEncryptField(b *testing.B) {
    key := make([]byte, 32)
    plaintext := []byte("test data")
    b.ResetTimer()
    b.ReportAllocs()
    for i := 0; i < b.N; i++ {
        _, _ = encryptField(plaintext, key)
    }
}
```

**规则：**
- `b.ResetTimer()` 排除 setup 时间
- `b.ReportAllocs()` 报告内存分配（性能优化的关键指标）
- 跑前关闭 CPU 节能、关闭后台进程

运行：

```bash
go test -bench=. -benchmem -run=^$ ./...
```

`-run=^$` 跳过普通测试，只跑 benchmark。

## 性能回归（benchstat）

```bash
# 改之前
go test -bench=. -count=10 -run=^$ ./pkg/crypto > old.txt

# 改完代码
go test -bench=. -count=10 -run=^$ ./pkg/crypto > new.txt

# 对比
go install golang.org/x/perf/cmd/benchstat@latest
benchstat old.txt new.txt
```

输出示例：

```
name              old time/op   new time/op   delta
EncryptField-8    1.20µs ±  2%  0.85µs ±  3%  -29.17%  (p=0.000)
```

**规则：**
- 优化前后必须用 benchstat 对比，不要凭感觉
- `-count=10` 至少跑 10 轮，统计才有意义
- p 值 < 0.05 才算显著

CI 中可以集成性能回归检查（如 [benchcheck](https://github.com/google/benchcheck)），关键路径性能下降 > 10% 阻断合并。

---

## 安全测试

| 工具 | 用途 | 集成 |
|------|------|------|
| `go vet` | 编译器静态检查 | `go vet ./...` |
| `staticcheck` | 高级静态分析 | golangci-lint 已含 |
| `gosec` | 安全静态扫描 | golangci-lint 已含 |
| `govulncheck` | 已知漏洞扫描 | CI 必跑 |

CI 配置详见 `08-delivery/cicd.md`，安全工具详情见 `11-security/secrets-supply-chain.md`。

```bash
# 本地手动跑
go vet ./...
gosec ./...
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...
```

## 自查

- [ ] 解析 / 协议 / 输入校验代码有 fuzz 测试
- [ ] 找到的 crash input 已加入 corpus
- [ ] 热点函数有 benchmark + ReportAllocs
- [ ] 性能优化前后跑了 benchstat 对比
- [ ] 本地跑过 `go vet` / `gosec` / `govulncheck`
