# 11.1 - 认证与授权

> 适用：实现登录、密码存储、JWT、RBAC、多租户隔离。

## 认证（Authentication）

### 密码存储

```go
// ✅ 推荐：bcrypt
import "golang.org/x/crypto/bcrypt"

hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
if err != nil { return err }

if err := bcrypt.CompareHashAndPassword(hash, []byte(input)); err != nil {
    return ErrInvalidCredentials
}

// ❌ 禁止
md5.Sum([]byte(password))
sha1.Sum([]byte(password))
```

### JWT

- 必须设置 `exp`（建议 ≤ 2h）和 `iat`
- 使用非对称算法（RS256/ES256），不用 HS256（除非密钥严格隔离）
- **Refresh Token** 单独存储、可吊销、绑定设备指纹
- 签名密钥支持多 key 并存以平滑轮转

### 登录保护

- 错误次数超阈值锁定账号或 IP（防爆破）
- 管理后台、敏感操作必须支持 MFA（TOTP / WebAuthn）

## 授权（Authorization）

### RBAC 优先

角色 → 权限 → 资源。检查必须在**业务层**（controlplane）执行，传输层（web）只是补充。

### 多租户隔离

```go
// ✅ 推荐：业务层强制租户隔离
func (s *EdgeService) GetEdge(ctx context.Context, edgeID int64) (*model.Edge, error) {
    user := userFromCtx(ctx)
    edge, err := s.repo.GetEdgeByID(edgeID)
    if err != nil { return nil, err }
    if edge.TenantID != user.TenantID {
        // 注意：返回 NotFound 而非 Forbidden，避免泄露资源存在
        return nil, ErrNotFound
    }
    return edge, nil
}
```

**禁止**：依赖前端传 `tenant_id`，必须从 context（认证后注入）取。

## 自查

- [ ] 密码用 bcrypt/argon2id
- [ ] JWT 有 `exp`，使用非对称算法
- [ ] Refresh token 可吊销
- [ ] 登录有失败限流
- [ ] 授权检查在业务层
- [ ] 多租户接口从 ctx 取 `tenant_id`，不信任前端
- [ ] 资源不存在/无权访问统一返回 NotFound
