# 13.2 - 大表 DDL 与 Backfill

> 适用：变更大表 schema、回填历史数据。

## 判断是否"大表"

经验阈值（MySQL）：

- 行数 > 100 万
- 数据量 > 1 GB

超过阈值禁止直接 `ALTER TABLE`，必须使用在线变更工具。

## 工具选型

| 工具 | 适用 | 说明 |
|------|------|------|
| **gh-ost** | MySQL | GitHub 出品，无触发器，基于 binlog |
| **pt-online-schema-change** | MySQL | Percona 出品，基于触发器 |
| **原生 Online DDL** | MySQL 8.0+ | 大部分 DDL 支持 `ALGORITHM=INPLACE, LOCK=NONE` |
| **pg_repack** | PostgreSQL | 无锁重建表 |

## 大表变更 checklist

- [ ] 评估变更耗时（工具会打印预估）
- [ ] 错峰执行（业务低峰期）
- [ ] 预留磁盘空间（临时表 ≈ 原表大小）
- [ ] 监控主从延迟，必要时暂停
- [ ] 保留操作日志
- [ ] DBA 或资深工程师在场

---

## Backfill 规范

### 何时需要

- 新增列需要初始化历史数据
- 数据修复（修 bug 导致的脏数据）
- 数据迁移（从旧表到新表）

### 规则

- **分批执行**：每批 1000-10000 行，避免长事务和锁等待
- **幂等**：失败后可重跑
- **可暂停**：有开关控制，不影响业务
- **可观测**：记录进度、速度、失败数（详见 `10-observability/metrics.md`）

```go
// ✅ 推荐：分批 + 游标
const batchSize = 1000

func backfillUserPhone(ctx context.Context, db *gorm.DB) error {
    var lastID int64 = 0
    for {
        var users []*model.User
        err := db.Where("id > ? AND phone IS NULL", lastID).
            Order("id ASC").
            Limit(batchSize).
            Find(&users).Error
        if err != nil { return err }
        if len(users) == 0 { return nil }

        for _, u := range users {
            u.Phone = derivePhone(u)
            if err := db.Save(u).Error; err != nil {
                log.Errorf("backfill user %d: %v", u.ID, err)
                continue
            }
        }
        lastID = users[len(users)-1].ID

        // 限速，避免打爆主库
        time.Sleep(100 * time.Millisecond)
    }
}
```

### 禁止事项

- ❌ 一条 SQL 更新全表（`UPDATE users SET phone = ...`）
- ❌ 业务高峰期执行
- ❌ 没有进度监控

## 自查

- [ ] 大表已用在线 DDL 工具
- [ ] 变更前备份 + 监控主从延迟
- [ ] Backfill 分批执行，可暂停可重试
- [ ] Backfill 速度有限速，避免打爆主库
