# 04 - 数据模型

> **设计先于实现**：先定数据落点和 schema，再写代码。生产 schema 变更走 `13-database-migration/`。

## 选型决策

| 数据特征 | 推荐 | 反例（不要用） |
|---------|------|--------------|
| 强一致、事务、关系查询、主数据 | **MySQL** | 不要用 Redis 当主存储 |
| 缓存、分布式锁、限流、计数器、排行榜、会话 | **Redis** | 不要用 Redis 存几 MB 的大对象 |
| 海量明细 / 报表 / 列式聚合 / 日志分析 | **ClickHouse** | 不要用 ClickHouse 做高频 UPDATE / 强一致事务 |
| 时间序列指标 / 监控 / 传感器 / IoT 上报 | **InfluxDB** | 不要把高基数维度（user_id、url）放 tag |

> 一个服务可能同时用多个：MySQL 存订单主数据，Redis 缓存热数据，ClickHouse 跑分析，InfluxDB 收监控。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 设计关系表、写 GORM 模型 / DAO、用事务 | `mysql.md` |
| 设计 Redis key、TTL、用分布式锁/限流/缓存 | `redis.md` |
| 设计 ClickHouse 表、选 engine、写聚合查询 | `clickhouse.md` |
| 设计 InfluxDB measurement、tag/field、retention | `influxdb.md` |

## 通用原则

1. **设计先于实现**：先明确字段、索引、关联，再写代码
2. **向后兼容**：新增字段必须有默认值或允许 NULL
3. **数据有保留期**：除主数据外，所有数据必须有清理策略（`13-database-migration/data-governance.md`）
4. **PII 加密 + 脱敏**：详见 `11-security/privacy-audit.md`
5. **大批量操作分批**：避免长事务、长锁、主从延迟

## 强制约束（不可违反）

- 生产 schema 变更走 migration 文件，禁止手改（`13-database-migration/migration.md`）
- 大表变更必须用在线 DDL 工具（`13-database-migration/online-ddl.md`）
- Redis key 必须设 TTL，例外需注释说明
- ClickHouse 写入必须批量
- InfluxDB tag 必须低基数
- 测试环境禁止使用生产数据明文
