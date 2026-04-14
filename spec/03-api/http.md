# 03.2 - HTTP 路由、响应、错误映射

> **适用**：写 HTTP handler、设计 RESTful 路由、统一响应格式、做错误码映射、获取客户端 IP、写自定义 HTTP handler。

## RESTful 路由

| 操作 | 方法 | 路径示例 |
|------|------|---------|
| 创建 | POST | `/api/v1/edges` |
| 查询单个 | GET | `/api/v1/edges/{id}` |
| 列表查询 | GET | `/api/v1/edges` |
| 更新 | PUT | `/api/v1/edges/{id}` |
| 部分更新 | PATCH | `/api/v1/edges/{id}` |
| 删除 | DELETE | `/api/v1/edges/{id}` |
| 子资源操作 | POST | `/api/v1/edges/{edge_id}/scan_application_tasks` |

**规则：**
- 资源名**复数形式**：`/edges`、`/devices`
- 子资源用嵌套路径
- 版本前缀：`/api/v1/`
- 多词资源用连字符或下划线，项目内一致

---

## 响应格式

所有 HTTP 响应统一三字段：

```go
type Response struct {
    Code    int32       `json:"code"`
    Message string      `json:"message"`
    Data    interface{} `json:"data,omitempty"`
}

// 成功
return &v1.LoginResponse{
    Code:    200,
    Message: "success",
    Data:    &v1.LoginData{Token: token, User: user},
}, nil
```

## HTTP 状态码 + 业务错误码

| 场景 | HTTP | Error Code |
|------|------|------------|
| 成功 | 200 | - |
| 参数错误 | 400 | `XXX_INVALID` |
| 未认证 | 401 | `CREDENTIALS_INVALID` |
| 权限不足 | 403 | `ACCOUNT_DISABLED` |
| 资源不存在 | 404 | `XXX_NOT_FOUND` |
| 冲突（重复创建） | 409 | `XXX_ALREADY_EXISTS` |
| 频率限制 | 429 | `RATE_LIMITED` |
| 服务器错误 | 500 | - |

## 错误映射

```go
import kratoserrors "github.com/go-kratos/kratos/v2/errors"

if errors.Is(err, iam.ErrLoginRateLimited()) {
    return nil, kratoserrors.New(429, "LOGIN_RATE_LIMITED", "尝试过于频繁，请稍后再试")
}
if errors.Is(err, iam.ErrInvalidCredentials()) {
    return nil, kratoserrors.New(401, "LOGIN_CREDENTIALS_INVALID", "账号或密码错误")
}
// 其他错误透传（框架处理为 500）
return nil, err
```

**规则：**
- 业务错误码全大写 + 下划线
- error code 在文档中维护，前后端共享
- 不要把内部错误明细返回给客户端（避免信息泄露）
- 4xx / 5xx 区别清楚：4xx 是客户端问题，5xx 是服务端问题

---

## 自定义 HTTP Handler

不适合 proto 定义的接口（文件上传、表单等）：

```go
// ✅ 推荐：复杂 HTTP 处理单独文件
srv.HandleFunc("/api/v1/iam/signup", web.handleSignupHTTP)
srv.HandleFunc("/api/v1/iam/avatar_upload", web.handleUploadAvatarHTTP)
```

文件命名：`<domain>_<action>_http.go`，如 `iam_signup_http.go`。

**仍然必须：**
- 写 Swagger 注释（详见 `middleware.md`）
- 返回统一响应格式
- 校验认证（如适用）
- 记录日志 + tracing

---

## 客户端 IP 获取

```go
// ✅ 推荐：依次检查代理头，兼容反向代理场景
func getClientIP(ctx context.Context) string {
    if httpReq, ok := kratoshttp.RequestFromServerContext(ctx); ok {
        // 1. X-Forwarded-For（多级代理取第一个）
        if forwarded := httpReq.Header.Get("X-Forwarded-For"); forwarded != "" {
            ips := strings.Split(forwarded, ",")
            if ip := strings.TrimSpace(ips[0]); ip != "" {
                return ip
            }
        }
        // 2. X-Real-IP
        if realIP := httpReq.Header.Get("X-Real-IP"); realIP != "" {
            return realIP
        }
        // 3. RemoteAddr
        ip, _, _ := net.SplitHostPort(httpReq.RemoteAddr)
        return ip
    }
    return ""
}
```

**安全提醒**：`X-Forwarded-For` 可被客户端伪造。仅在反向代理后可信，且代理必须重写头。

## 自查

- [ ] 路由遵循 RESTful，资源用复数
- [ ] 响应统一三字段格式
- [ ] HTTP 状态码 + 业务错误码组合正确
- [ ] 错误信息不暴露内部细节
- [ ] 自定义 handler 仍写 Swagger + 鉴权 + 日志
- [ ] 客户端 IP 正确处理代理头
