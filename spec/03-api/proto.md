# 03.1 - Proto 优先设计

> **适用**：写 / 改 `.proto` 文件、生成代码、设计请求/响应消息。

## Proto 文件规范

```protobuf
// api/order/v1/order.proto
syntax = "proto3";

package order.v1;
option go_package = "github.com/your-org/your-repo/api/order/v1;v1";

// ✅ 推荐：请求/响应命名遵循 <动词><资源>Request/Response
message CreateOrderRequest {
    string name = 1;
    string description = 2;
}

message CreateOrderResponse {
    int32 code = 1;
    string message = 2;
    Order data = 3;
}

// ✅ 列表接口包含分页字段
message ListOrdersRequest {
    int32 page = 1;
    int32 page_size = 2;
}

message ListOrdersResponse {
    int32 code = 1;
    string message = 2;
    repeated Order data = 3;
    int64 total = 4;
}
```

## 字段编号规则

- 字段编号一旦上线**永不复用**（即使删除字段也不能重新分配）
- 1-15 占 1 byte，留给高频字段
- 16-2047 占 2 byte
- 19000-19999 是 protobuf 保留区，不能用

```protobuf
message Order {
    int64 id = 1;          // 高频
    string name = 2;       // 高频
    string description = 3;
    // 删除字段时用 reserved，防止后人复用编号
    reserved 4;
    reserved "old_field_name";
    int64 created_at = 5;
}
```

## 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| package | `<bc>.v<n>` | `order.v1` |
| message | PascalCase | `CreateOrderRequest` |
| field | snake_case | `user_id`、`page_size` |
| enum 类型 | PascalCase | `OrderStatus` |
| enum 值 | `<TYPE>_<NAME>`，全大写 | `ORDER_STATUS_ACTIVE` |
| service | `<Domain>Service` | `OrderService` |
| rpc | PascalCase 动词 | `CreateOrder` |

## Enum 设计

```protobuf
// ✅ 推荐：第 0 个值必须是 UNSPECIFIED
enum OrderStatus {
    ORDER_STATUS_UNSPECIFIED = 0;
    ORDER_STATUS_ACTIVE = 1;
    ORDER_STATUS_INACTIVE = 2;
    ORDER_STATUS_DELETED = 3;
}
```

**规则：**
- 0 值必须是 `UNSPECIFIED`，避免误判默认值
- 枚举值前缀和类型名一致（避免命名冲突）
- 删除值用 `reserved`

## 代码生成

```bash
protoc --go_out=. --go-grpc_out=. --go-http_out=. api/order/v1/order.proto
```

生成步骤必须封装为 Makefile `proto` target，统一本地和 CI 的入口（详见 `08-delivery/makefile.md`）：

```bash
make proto
```

**禁止**在 CI / README / 新人文档里直接写 `protoc ...` 命令——一定走 `make proto`。

**禁止：**
- ❌ 手工修改生成的 `.pb.go` 文件
- ❌ 把生成代码加进 `.gitignore`（必须提交，方便 review 接口变更）
- ❌ 不同 proto 版本混用（`v1` 和 `v2` 各有 package）

## 自查

- [ ] Proto 命名遵循规范（PascalCase / snake_case）
- [ ] 字段编号 1-15 留给高频字段
- [ ] 删除字段用 `reserved` 占位
- [ ] enum 第 0 个值是 `UNSPECIFIED`
- [ ] 列表接口有 `page` / `page_size` / `total`
- [ ] 没有手改生成代码
- [ ] 生成代码已提交到仓库
