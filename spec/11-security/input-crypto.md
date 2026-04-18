# 11.2 - 输入校验、注入防护、加密

> 适用：处理任何用户输入、外部 URL、文件路径、字段加密。

## 输入校验三原则

1. **白名单优于黑名单**
2. **校验在服务端**（前端校验只是 UX）
3. **类型 + 范围 + 格式**三层校验

```go
// ✅ 推荐：validator + 业务规则
type CreateOrderRequest struct {
    Name     string `json:"name"     validate:"required,min=1,max=64,alphanum"`
    Quantity int    `json:"quantity" validate:"required,min=1,max=9999"`
}

if err := validate.Struct(req); err != nil {
    return nil, errs.NewInvalidParam(err.Error())
}
```

## 注入防护

### SQL 注入

```go
// ✅ GORM 参数化
db.Where("user_id = ? AND status = ?", userID, status).Find(&orders)

// ❌ 字符串拼接
db.Where(fmt.Sprintf("user_id = %d", userID)).Find(&orders)
db.Raw("SELECT * FROM users WHERE name = '" + name + "'").Scan(&users)
```

### 命令注入

```go
// ✅ exec.Command 分离参数
cmd := exec.CommandContext(ctx, "ffmpeg", "-i", userInputFile, "-o", outputPath)

// ❌ shell 拼接
exec.Command("sh", "-c", "ffmpeg -i " + userInputFile)
```

### 路径穿越

```go
// ✅ 清理路径并校验前缀
clean := filepath.Clean(userPath)
abs, err := filepath.Abs(filepath.Join(baseDir, clean))
if err != nil || !strings.HasPrefix(abs, baseDir) {
    return ErrInvalidPath
}
```

### SSRF

```go
// ✅ 解析后校验目标 IP
func safeGet(ctx context.Context, rawURL string) (*http.Response, error) {
    u, err := url.Parse(rawURL)
    if err != nil { return nil, err }
    ips, err := net.LookupIP(u.Hostname())
    if err != nil { return nil, err }
    for _, ip := range ips {
        if ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
            return nil, ErrPrivateAddress
        }
    }
    return httpClient.Do(req)
}
```

### 反序列化

- ❌ 禁止 `gob` 反序列化不可信数据
- ❌ 禁止 `encoding/xml` 处理外部 XML（XXE）
- ✅ JSON 反序列化使用 `DisallowUnknownFields()` 防字段污染

## 字段加密

| 数据类型 | 加密方式 |
|---------|---------|
| 密码 | bcrypt / argon2id（不可逆） |
| API Token | SHA256 哈希存储，原文只显示一次 |
| PII（手机/身份证） | AES-256-GCM 字段加密 |
| 数据库 | 启用 TDE |
| 备份 | 加密 + 密钥分离存储 |

```go
// ✅ AES-GCM 字段加密
func encryptField(plaintext, key []byte) ([]byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil { return nil, err }
    gcm, err := cipher.NewGCM(block)
    if err != nil { return nil, err }
    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil { return nil, err }
    return gcm.Seal(nonce, nonce, plaintext, nil), nil
}
```

## 传输加密

- 所有外部流量必须 HTTPS（TLS 1.2+，建议 1.3）
- 内部服务间通信优先 mTLS
- 数据库连接启用 TLS

## 限流与熔断

```go
// ✅ golang.org/x/time/rate
limiter := rate.NewLimiter(rate.Limit(100), 200) // 100/s，桶容量 200
if !limiter.Allow() {
    return nil, errs.NewRateLimited("请求过于频繁")
}
```

- 第三方调用必须有超时（默认 5s）
- 连续失败超阈值触发熔断（参考 `sony/gobreaker`）

## CSRF / CORS

- API 服务默认 `Access-Control-Allow-Origin` 白名单
- Cookie 认证接口必须校验 CSRF token 或 `SameSite=Strict`

## 自查

- [ ] 输入有白名单校验（类型 + 范围 + 格式）
- [ ] SQL 全部参数化
- [ ] 命令/路径/URL 已防注入/穿越/SSRF
- [ ] PII 字段加密存储
- [ ] 外部调用有超时和限流
- [ ] HTTPS / TLS 已启用
