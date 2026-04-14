# 13.1 - Migration 工具与兼容性

> 适用：写 schema 变更脚本、新增/修改字段、确保滚动发布兼容。

## 工具与目录

### 工具选型

- **推荐**：`golang-migrate/migrate` 或 `pressly/goose`
- **不推荐**：只用 GORM `AutoMigrate`（生产不可控、不可回滚、不可审计）
- **团队约定**：选定一个，不混用

### 目录结构

```
db/
├── migrations/
│   ├── 20260414100000_create_users.up.sql
│   ├── 20260414100000_create_users.down.sql
│   ├── 20260414110000_add_users_email_index.up.sql
│   └── 20260414110000_add_users_email_index.down.sql
├── seeds/                    # 基础数据
│   └── 001_init_roles.sql
└── README.md
```

### 命名规范

```
<timestamp>_<verb>_<object>.<direction>.sql
```

- 时间戳精确到秒，避免冲突
- 动词：`create` / `alter` / `drop` / `add_column` / `add_index` / `rename` / `backfill`
- 文件一旦合并到 main **禁止修改**，只能追加新 migration 修正

---

## Expand & Contract（兼容滚动发布）

滚动发布期间新旧代码同时运行，schema 变更必须分步进行。

```
Expand   → Migrate → Contract
扩展      迁移     收缩
```

### 场景 A：重命名列 `old_name` → `new_name`

**禁止**：一步 `ALTER TABLE ... CHANGE old_name new_name`

**正确步骤**：

```
Release 1 (Expand)
  - 新增列 new_name（允许 NULL）
  - 代码双写 old_name 和 new_name
  - 代码读取优先 new_name，fallback old_name

Release 2 (Backfill)
  - 后台任务填充 new_name（详见 online-ddl.md）
  - 验证一致性

Release 3 (Contract)
  - 代码只读写 new_name
  - 确认无流量读 old_name

Release 4 (Cleanup)
  - DROP COLUMN old_name
```

### 场景 B：新增 NOT NULL 列

**禁止**：直接 `ADD COLUMN x NOT NULL`（旧代码 INSERT 失败）

**正确步骤**：

```
1. ADD COLUMN x ... NULL DEFAULT ...
2. Backfill 数据
3. 代码更新为强制写入 x
4. ALTER COLUMN x SET NOT NULL
```

### 场景 C：删除列

**禁止**：直接 `DROP COLUMN`（旧代码 SELECT * 会爆）

**正确步骤**：

```
1. 代码停止写入
2. 代码停止读取（SELECT 指定列）
3. 观察 1-2 个发布周期确认无流量
4. DROP COLUMN
```

---

## CI / CD 集成

```yaml
jobs:
  migrate-dryrun:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations on throwaway DB
        run: |
          docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=pass -p 3306:3306 mysql:8.0
          sleep 20
          migrate -path db/migrations -database 'mysql://root:pass@tcp(localhost:3306)/test' up
          # 验证 down 也能执行
          migrate -path db/migrations -database 'mysql://root:pass@tcp(localhost:3306)/test' down -all
```

## 生产执行规范

1. **提前 review**：migration SQL 必须有至少一位 DBA / 资深工程师 review
2. **分环境执行**：dev → staging → prod，每步验证
3. **变更前备份**：快照 + binlog 位点记录
4. **变更窗口**：核心表必须在维护窗口执行
5. **记录留痕**：每次执行写入 `schema_migrations` 审计表

```bash
# 升级
migrate -path db/migrations -database "$DSN" up

# 回滚最后一步
migrate -path db/migrations -database "$DSN" down 1

# 查看当前版本
migrate -path db/migrations -database "$DSN" version
```

## 自查

- [ ] 变更以 migration 文件提交
- [ ] 有配套的 `down.sql`
- [ ] 兼容滚动发布（expand-contract）
- [ ] 新增 NOT NULL 列已先填充默认值
- [ ] 删列：先停写再停读再删
- [ ] CI 已 dry-run up + down
