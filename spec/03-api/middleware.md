# 03.3 - Swagger 注释与认证中间件

> **适用**：写 handler 的 Swagger 注释、接入认证中间件、配置公开路由白名单。

## Swagger 注释

所有公开 handler 必须有完整 Swagger 注释，缺一不可：

```go
// @Summary Login
// @Tags User
// @Accept json
// @Produce json
// @Param params body v1.LoginRequest true "登录请求"
// @Success 200 {object} v1.LoginResponse
// @Failure 401 {object} v1.ErrorResponse
// @Failure 429 {object} v1.ErrorResponse
// @Router /api/v1/users/login [post]
func (s *UserService) Login(ctx context.Context, req *v1.LoginRequest) (*v1.LoginResponse, error) {
```

**必填字段：**

| 字段 | 说明 |
|------|------|
| `@Summary` | 一句话描述 |
| `@Tags` | 分组（按业务域） |
| `@Param` | 参数（含路径、query、body） |
| `@Success` | 成功响应类型 |
| `@Failure` | 关键错误响应（401、403、429、500） |
| `@Router` | 路径 + HTTP 方法 |

生成命令（以 swaggo/swag 为例）：

```bash
swag init -g cmd/api/main.go -o docs/swagger/
```

**禁止：**
- ❌ 手动修改 `docs/swagger/` 下的生成文件
- ❌ Swagger 注释与实际行为不符（不更新就是说谎）

---

## 认证中间件

> 密码存储、JWT 算法选择、Refresh Token、登录限流等细节详见 `11-security/auth.md`。本节只讲中间件层的接入。

以下示例以 Kratos middleware 为例；gin / hertz / chi 有各自的 middleware API，但职责完全一致：**从 Authorization header 解析 token → 校验 → 把认证用户注入 context**。

```go
// Kratos 风格
func AuthMiddleware(authSvc AuthService) middleware.Middleware {
    return func(handler middleware.Handler) middleware.Handler {
        return func(ctx context.Context, req interface{}) (reply interface{}, err error) {
            if isPublicRoute(ctx) {
                return handler(ctx, req)
            }
            token := extractBearerToken(ctx)
            user, err := authSvc.GetUserByToken(ctx, token)
            if err != nil {
                return nil, kratoserrors.New(401, "UNAUTHORIZED", "未认证")
            }
            ctx = context.WithValue(ctx, userKey, user)
            return handler(ctx, req)
        }
    }
}
```

```go
// gin 风格
func AuthMiddleware(authSvc AuthService) gin.HandlerFunc {
    return func(c *gin.Context) {
        if isPublicRoute(c) { c.Next(); return }
        user, err := authSvc.GetUserByToken(c.Request.Context(), extractBearerToken(c.Request))
        if err != nil {
            c.AbortWithStatusJSON(401, Response{Code: 401, Message: "未认证"})
            return
        }
        c.Set("user", user)
        c.Next()
    }
}
```

## 公开路由白名单

```go
// ✅ 推荐：公开路由集中维护，非白名单的路由默认要鉴权
var publicRoutes = map[string]bool{
    "/api/v1/users/login":   true,
    "/api/v1/users/signup":  true,
    "/api/v1/users/captcha": true,
    "/healthz":              true,
    "/readyz":               true,
    "/metrics":              true,
}

// 具体实现依框架而定：Kratos 用 transport.OperationFromContext(ctx)；
// gin 用 c.FullPath()；hertz / chi 有各自的路由 API。
```

**规则：**
- **默认拒绝**：未在白名单的路由必须鉴权
- 白名单走 review，新增公开路由需要明确理由
- 健康检查端点 `/healthz`、`/readyz`、`/metrics` 必须公开（详见 `10-observability/slo-alerting.md`）

## Context 传值

```go
// ✅ 用 typed key，避免字符串 key 冲突
type ctxKey int
const userKey ctxKey = iota

ctx = context.WithValue(ctx, userKey, user)

// 取值
func userFromCtx(ctx context.Context) *AuthUser {
    if u, ok := ctx.Value(userKey).(*AuthUser); ok {
        return u
    }
    return nil
}
```

**禁止**：用裸字符串 key（容易和别人冲突）。

## 自查

- [ ] Handler 有完整 Swagger 注释（5 个必填字段）
- [ ] Swagger 注释与代码行为一致
- [ ] 默认所有路由要鉴权，公开路由走白名单
- [ ] 健康检查端点在白名单
- [ ] context 传值用 typed key
