# 04.1 - MySQL / GORM

> **适用**：设计关系表、写 GORM 模型 / DAO、用事务、写列表查询。
>
> 生产 schema 变更和大表 DDL 见 `13-database-migration/`。

## 表结构设计

### 字段命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 主键 | `id`，bigint，自增 | `id` |
| 时间字段 | snake_case，`_at` 后缀 | `created_at`、`updated_at`、`deleted_at` |
| 外键 | `<关联表单数>_id` | `user_id`、`edge_id` |
| 状态字段 | `status`，tinyint 或 varchar | `status` |
| 布尔字段 | `is_<描述>` 或 `<描述>_enabled` | `is_active`、`email_verified` |

### 必须包含的基础字段

```sql
`id`         BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
`created_at` DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
`updated_at` DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
`deleted_at` DATETIME(3)  NULL     DEFAULT NULL,  -- 软删除
```

### 索引设计原则

- 软删除字段 `deleted_at` 必须建索引
- 外键字段必须建索引
- 高频查询条件字段建索引
- 联合索引遵循最左前缀原则
- 单表索引数量不超过 5 个
- 字符串索引考虑前缀长度（`varchar(255)` 不要全建）
- `OR` 查询通常用不上索引，改写成 `UNION` 或拆查询

### 字段类型选择

| 用途 | 推荐 | 避免 |
|------|------|------|
| 金额 | `DECIMAL(20,4)` | `FLOAT` / `DOUBLE` |
| 状态枚举 | `TINYINT UNSIGNED` | `VARCHAR` |
| ID 引用 | `BIGINT UNSIGNED` | `INT` |
| 大文本 | `TEXT` 单独表 | 主表 `LONGTEXT` |
| JSON | `JSON` | `TEXT` 存序列化 |
| IP | `VARBINARY(16)` | `VARCHAR(15)` |

---

## GORM 模型

```go
type User struct {
    ID        int64          `gorm:"column:id;primaryKey;autoIncrement"        json:"id"`
    CreatedAt time.Time      `gorm:"column:created_at;autoCreateTime"          json:"created_at"`
    UpdatedAt time.Time      `gorm:"column:updated_at;autoUpdateTime"          json:"updated_at"`
    DeletedAt gorm.DeletedAt `gorm:"column:deleted_at;index"                   json:"-"`
    Email     string         `gorm:"column:email;type:varchar(255);not null;default:'';uniqueIndex" json:"email"`
    Name      string         `gorm:"column:name;type:varchar(128);not null;default:''"  json:"name"`
    Status    int8           `gorm:"column:status;type:tinyint;not null;default:0"      json:"status"`
}

func (User) TableName() string { return "users" }
```

**规则：**
- 每个模型必须实现 `TableName()`
- 所有字段必须显式 `gorm:"column:..."` 标签
- 软删除用 `gorm.DeletedAt` + `json:"-"`
- `varchar` 字段必须 `not null` 和 `default`
- 文件命名：`model_<entity>.go`

---

## DAO 接口

### Repo 聚合接口

```go
// pkg/liaison/repo/repo.go
type Repo interface {
    CreateUser(user *model.User) error
    GetUserByID(id int64) (*model.User, error)
    GetUserByEmail(email string) (*model.User, error)
    ListUsers(page, pageSize int) ([]*model.User, int64, error)
    Close() error
}
```

### DAO 接口（支持事务）

```go
type Dao interface {
    Begin() Dao
    Commit() error
    Rollback() error
    // ... 数据操作方法
}
```

### 并发安全的 DAO 实现

```go
// ✅ 推荐：读写锁保护 db/tx 切换
type dao struct {
    mu sync.RWMutex
    db *gorm.DB
    tx *gorm.DB
}

func (d *dao) getDB() *gorm.DB {
    d.mu.RLock()
    defer d.mu.RUnlock()
    if d.tx != nil {
        return d.tx
    }
    return d.db
}

func (d *dao) Begin() Dao {
    d.mu.Lock()
    defer d.mu.Unlock()
    tx := d.db.Begin()
    return &dao{db: d.db, tx: tx}
}
```

---

## 事务

```go
// ✅ defer recover 保证事务一定被回滚
txDao := s.dao.Begin()
defer func() {
    if r := recover(); r != nil {
        txDao.Rollback()
    }
}()

if err := txDao.CreateEdge(edge); err != nil {
    txDao.Rollback()
    return err
}
if err := txDao.UpdateUserQuota(userID, quota); err != nil {
    txDao.Rollback()
    return err
}
return txDao.Commit()
```

**规则：**
- 需要原子性的多步操作必须用事务
- 事务 DAO 不跨 goroutine 共享
- 事务内禁止调用第三方 API / 慢操作（避免长锁）
- 事务尽可能短

---

## 列表查询

```go
// ✅ 列表查询必须分页
func (d *dao) ListEdges(page, pageSize int, userID int64) ([]*model.Edge, int64, error) {
    var edges []*model.Edge
    var total int64

    db := d.getDB().Model(&model.Edge{}).Where("user_id = ?", userID)
    if err := db.Count(&total).Error; err != nil {
        return nil, 0, err
    }
    if err := db.Offset((page - 1) * pageSize).Limit(pageSize).Find(&edges).Error; err != nil {
        return nil, 0, err
    }
    return edges, total, nil
}
```

**深翻页问题**：`OFFSET 100000` 会扫描前 10 万行。深翻页用游标：

```go
// ✅ 游标分页：基于 id > last_id
db.Where("id > ? AND user_id = ?", lastID, userID).
    Order("id ASC").Limit(pageSize).Find(&edges)
```

---

## AutoMigrate（仅限开发 / 集成测试）

> ⚠️ **生产环境禁用 AutoMigrate**。生产 schema 变更走版本化 migration 工具，详见 `13-database-migration/migration.md`。
>
> AutoMigrate 仅用于：本地开发拉起干净库 / 集成测试初始化 schema / 单机自部署的快速演进期。

```go
func (d *dao) initDB() error {
    if !d.conf.AutoMigrateEnabled { // 生产配置项关闭
        return nil
    }
    return d.db.AutoMigrate(
        &model.User{},
        &model.Edge{},
        &model.Device{},
    )
}
```

---

## 连接池配置

```go
sqlDB, _ := db.DB()
sqlDB.SetMaxOpenConns(50)        // 最大连接数
sqlDB.SetMaxIdleConns(10)        // 空闲连接数
sqlDB.SetConnMaxLifetime(time.Hour)
sqlDB.SetConnMaxIdleTime(10 * time.Minute)
```

经验值：单实例 `MaxOpenConns ≈ (业务峰值 QPS × 平均 SQL 耗时 ms) / 1000`，留 20% 余量。

## 自查

- [ ] 表有 id / created_at / updated_at / deleted_at
- [ ] 外键、查询条件字段有索引
- [ ] 字段类型选对（金额非 float、状态非 varchar）
- [ ] 列表查询有分页，深翻页用游标
- [ ] 事务内无第三方 API 调用
- [ ] 连接池配置合理
- [ ] PII 字段已加密（`11-security/privacy-audit.md`）
