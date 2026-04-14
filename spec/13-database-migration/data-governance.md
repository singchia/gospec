# 13.3 - 数据治理：分级、保留、权限

> 适用：设计数据保留策略、配置数据库账号权限、应对 GDPR/个保法的删除/导出权。

## 数据分级

| 级别 | 定义 | 示例 | 保留策略 |
|------|------|------|---------|
| **L0 元数据** | 系统运行必需 | 配置、字典 | 永久 |
| **L1 业务主数据** | 核心业务实体 | 用户、订单 | 永久 / 按合规 |
| **L2 业务流水** | 业务过程数据 | 登录记录、操作日志 | 180 天 - 2 年 |
| **L3 临时数据** | 缓存、会话 | session、code | 按业务需要（分钟-天） |
| **L4 审计日志** | 合规留痕 | 敏感操作日志 | ≥ 180 天，按法规 |

## 保留策略实现

```go
// ✅ 推荐：定时任务 + 配置化
type RetentionPolicy struct {
    Table    string
    Column   string        // 时间字段
    Keep     time.Duration
    BatchSize int
}

var policies = []RetentionPolicy{
    {Table: "login_logs", Column: "created_at", Keep: 180 * 24 * time.Hour, BatchSize: 1000},
    {Table: "email_codes", Column: "created_at", Keep: 24 * time.Hour, BatchSize: 5000},
}

// 每日凌晨执行
func runRetention(ctx context.Context, db *gorm.DB) {
    for _, p := range policies {
        threshold := time.Now().Add(-p.Keep)
        for {
            res := db.Exec(
                fmt.Sprintf("DELETE FROM %s WHERE %s < ? LIMIT ?", p.Table, p.Column),
                threshold, p.BatchSize,
            )
            if res.RowsAffected == 0 { break }
            time.Sleep(100 * time.Millisecond)
        }
    }
}
```

## 软删除 vs 硬删除

| 选择 | 适用 |
|------|------|
| 软删除 (`deleted_at`) | 业务核心数据，可能需恢复 |
| 硬删除 | 日志、缓存、临时数据；合规要求（GDPR 删除权） |

GDPR / 个保法的访问权、删除权、可携权实现见 `11-security/privacy-audit.md`。

---

## 数据库账号权限

### 最小权限原则

| 账号 | 权限 |
|------|------|
| 应用 | SELECT/INSERT/UPDATE/DELETE（业务表） |
| 只读报表 | SELECT（指定库） |
| Migration | CREATE/ALTER/INDEX（仅执行 migration 时使用） |
| 运维 | 全部（审计 + 双人） |

### 禁止事项

- ❌ 应用账号有 `DROP` 权限
- ❌ 应用账号有 `GRANT` 权限
- ❌ 测试环境账号能连生产
- ❌ 密码明文存储在配置文件

---

## 数据库监控指标

数据库层必须埋点（详见 `10-observability/metrics.md`）：

| 指标 | 告警阈值 |
|------|---------|
| 主从延迟 | > 5s |
| 连接数使用率 | > 80% |
| 慢查询数量 | > 基线 2x |
| 磁盘使用率 | > 80% |
| 死锁次数 | > 0 |
| 主库 CPU | > 70% |

## 自查

- [ ] 新表已分级（L0-L4）
- [ ] 有保留策略，自动清理
- [ ] 应用账号权限最小化
- [ ] 测试环境账号无生产访问
- [ ] 关键查询有监控指标
