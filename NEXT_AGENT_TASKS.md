# windows-cj 生产质量任务

创建时间：2026-05-15 14:24 +08:00

本文档取代之前的滚动对齐日志。旧日志已经删除，因为它更像长会话流水账，存在过时的 round/review 顺序信息，不再适合作为下一任 agent 的执行入口。历史细节仍可通过 git 历史查看。

## 当前基线

- 最近已知提交基线：`58c8770c fix: clean replaced abi arrays`。
- 不要直接恢复已放弃的未提交 Round140 代码。
- 上一轮会话识别出一个可能的 `AbiArray<HString>.get()` 所有权问题，但相关代码未提交。下一任 agent 应把它当作新的候选问题处理：先写红测，确认期望的所有权契约，只有测试证明真实 bug 后再实现，并在提交前请求 review。

## 目标

通过证明并强制执行 ABI、所有权、生成 wrapper 的不变量，让 `windows-cj` 达到生产质量。

目标是以 `ref/windows-rs` 为行为参考，实现 Win32/WinRT ABI 行为等价；不是逐字匹配 API 形态。不要引入不适合仓颉的外部语言概念。优先使用仓颉范式：`Resource.close()`、显式资源释放责任 wrapper、单类型特化代码生成、共享 helper API。

这里的“资源释放责任”不是 Rust 的借用/生命周期/所有权类型系统。它只表示某个仓颉对象负责在确定时机调用外部资源的释放 API，例如 COM `Release`、HSTRING 删除或 `CoTaskMemFree`；仓颉对象之间的普通引用仍由 GC 管理。

## 硬性规则

- 编辑仓颉代码前，必须通过 Cangjie MCP 查询官方文档，确认本次编辑会用到的语法/API。
- 运行任何 `cjpm` 命令前必须设置 `cjHeapSize=32GB`。
- 执行仓颉编译产物必须使用 `cjv exec <binary>`，不得直接运行二进制。
- `ref/windows-rs` 是行为参考且只读。可以在任务文档、审查记录和交接说明中提及它；不要在仓颉源码、测试代码、源码注释或生成产物中写入 `windows-rs` 名称。
- 自动化不要使用 shell 脚本；使用 Python。
- commit 中不要添加 `Co-Authored-By` 行。
- 每个实现批次完成后必须派生 review agent。review 没有 P0/P1/P2 问题后才能提交。

## 质量不变量

将这些条目作为 review 清单和静态审计依据：

- owned ABI 构造路径必须拒绝成功 HRESULT 携带的 null owned pointer，并返回/抛出 `E_POINTER`；明确设计为 borrowed/probe 的 view 路径可以继续接受 null。
- 每个 owned `QueryInterface` 结果必须要么返回给调用方，要么被确定性关闭。
- 仅用于祖先接口转发的临时 interface wrapper，在成功和失败路径都必须关闭。
- HSTRING/BSTR 的每个 take/copy/borrow 路径都必须有唯一清晰的释放方。
- CoTaskMem array 必须精确转移一次所有权，或在所有失败路径释放。
- out-parameter array 在元素投影部分失败时，必须清理已经 materialize 的元素。
- 生成的 vtable thunk 必须在 dispatch 前拒绝非零容量的 null buffer；ABI 允许时仍应允许零容量 null buffer。
- HRESULT 失败必须传播，不允许通过未使用结果的 `.ok()` 被忽略。
- 生成的泛型 ABI 特化必须保留 scalar/copy struct 的 direct value ABI，以及 HSTRING/interface 类型的 handle ABI。
- `Resource.close()` 和析构器必须使用 closed 标记避免 double free。

## 工作计划

### 1. 建立静态审计门禁

创建或扩展 Python 检查，覆盖高风险模式：

- `fromAbiTake` 路径可能接受 null owned pointer。
- `QueryInterface` 结果没有被 `try`/`close` 包住，也没有返回给调用方。
- `HRESULT(...).ok()` 的结果被忽略。
- `CoTaskMemAlloc` 或 raw HSTRING slot materialization 缺少失败清理。
- 生成的 thunk 方法缺少非零 null-buffer guard。

验收标准：

- 审计可以从 `python scripts/check_workspace_setup.py` 触发，或由它调用一个命名清晰的 Python 脚本。
- 已知安全例外必须在脚本中用窄模式记录，不能用宽泛白名单掩盖问题。

### 2. 将覆盖率提升为类型类别矩阵

不要为每个 API 机械补一个测试。应按代表性类型类别构建生成式或 helper 驱动测试：

- Copy scalar：`Int32`、`UInt32`、`Bool`。
- Copy struct：`GuidValue`、`DateTime`、`TimeSpan`、`Rect`。
- Clone handle：`HString`。
- COM interface：owned、borrowed、nullable。
- 各类型类别的 array。
- 集合表面：vector、vector view、map、map view、iterator。

验收标准：

- 每次生成器调用只生成一个类型特化，让失败能指向一个明确 ABI 形态。
- 如果问题涉及 ABI 签名或 thunk guard，测试必须通过直接 vtable 调用证明行为。

### 3. 统一生成 wrapper 语义

将重复修复下沉到共享 helper 或生成器：

- owned output materialization。
- HSTRING input staging 和 cleanup。
- COM interface input borrowing 与 out-slot ownership。
- copy、HSTRING、interface 元素的 array input/output staging。
- collection `GetMany` 与 `ReplaceAll` 校验。

验收标准：

- 一个 helper 的变化能覆盖对应的全部 wrapper 路径。
- 新生成输出必须最小化 churn，并经过 ABI 形态 review。

### 4. 增加真实 Windows smoke 测试

fake vtable 单元测试是必要的，但不足以证明生产质量。需要增加一层小型 smoke 测试，覆盖真实系统 ABI 边界：

- activation factory lookup 的失败路径，以及可用时的成功路径。
- HSTRING 通过真实 WinRT 调用 roundtrip。
- property value array create/get roundtrip。
- 通过投影接口进行基础集合迭代。
- 如果有稳定测试对象，覆盖 async action/operation join。

验收标准：

- smoke 测试必须隔离、确定性强；平台 API 不可用时用清晰条件跳过。
- smoke 测试必须通过 `cjv exec` 执行。

### 5. 维护 package readiness 矩阵

在本文档或后续生产就绪文档中维护 readiness 表：

- `windows-strings`：handle 生命周期、pointer view、BSTR/HSTRING 覆盖。
- `windows-core`：COM identity、array、factory、generic ABI bridge。
- `windows-runtime`：WinRT collection、delegate、async、property value。
- `windows`：生成的 Win32 签名和类型 alias。
- `windows-services`、`windows-threading`、`windows-registry`、`windows-version`：smoke 与基础 ABI 覆盖。

验收标准：

- 每个 package 都有状态：`Blocked`、`Needs tests`、`Candidate` 或 `Production-ready`。
- 每个未 ready 的 package 都必须有具体的下一步测试或修复任务。

## 下一任 agent 的第一批任务

1. ~~确认 worktree 除本文档新增和旧日志删除外没有其他变更。~~（已完成）
2. ~~跑基线验证。~~（已完成）
3. ~~重新评估 `AbiArray<HString>.get()` 所有权候选问题。~~（已修，提交 `ba017c29`：`ProjectedAbiArrayStorage.get()` 现在返回独立 owned clone；红测固化契约。）
4. ~~添加第一条静态审计检查。~~（已完成，提交 `1846e803`：`scripts/check_ignored_results.py` 检测忽略的 `Result.ok()`，由 `check_workspace_setup.py` 调用。已记录的盲点：if/else 分支末尾、match 分支末尾。）
5. 启动 array 和 collection thunk 的类型类别测试矩阵。**当前进度：见下文"类型类别测试矩阵"小节。** 第一个推荐目标：`vector_hstring_abi_test.cj`。

## 类型类别测试矩阵

跟踪 `NEXT_AGENT_TASKS.md` 列出的类型类别覆盖。目标：每个集合表面 × 每个类型类别 至少一个单类型特化测试。失败应能指向唯一 ABI 形态。

### 类型类别

- **Copy scalar**：`Int32`、`UInt32`、`Bool`、`Int16`、`UInt16`、`Int64`、`UInt64`、`Float32`、`Float64`、`UInt8` — direct value ABI。
- **Copy struct**：`GuidValue`、`DateTime`、`TimeSpan`、`Rect`、`Point`、`Size` — direct value ABI。
- **Clone handle**：`HString` — handle (`CPointer<Unit>`) ABI。
- **COM interface**：owned、borrowed、nullable — handle ABI。

### 表面覆盖（2026-05-15 快照）

| 表面 | Copy scalar | Copy struct | HString | COM interface |
| --- | --- | --- | --- | --- |
| Vector | ✅ `vector_int32_abi_test.cj` 等每个标量宽度一个 | ✅ `vector_copy_struct_abi_test.cj`, `vector_datetime_abi_test.cj` | ✅ `vector_hstring_abi_test.cj` | ❌ |
| Vector view | ✅ `vector_view_uint8_abi_test.cj` 等 | ❌ | ❌ | ❌ |
| Map | ✅ `map_int32_abi_test.cj` 等 | partial (`map_int32_vector_view_abi_test.cj` 嵌套) | ✅ `map_int32_hstring_abi_test.cj`, `map_uint32_hstring_abi_test.cj` | ❌ |
| Map view | partial (`map_view_int32_generic_abi_test.cj`) | ❌ | ❌ | ❌ |
| Iterator | ❌ | ❌ | ❌ | ❌ |
| Array (in/out/replace) | partial (`vector_int32_generic_abi_test.cj` GetMany/ReplaceAll；`property_value_array_abi_test.cj`) | ❌ | ❌ | ❌ |

### 推荐顺序

1. ~~`vector_hstring_abi_test.cj`~~（已完成）：直接走泛型 `IVectorVtbl.new<Identity, HString>` + `IIterableVtbl.new<Identity, HString>`。覆盖 wrapper 路径（SetAt/InsertAt/Append/IndexOf）和直接 vtable 路径（HSTRING raw handle in/out，含 GetAt out-slot）。
2. `vector_interface_abi_test.cj` — IVector<IInspectable>，覆盖 owned/borrowed slot 转换。
3. `vector_view_hstring_abi_test.cj`、`vector_view_interface_abi_test.cj`。
4. `map_hstring_*_abi_test.cj` — HString key。
5. `iterator_*_abi_test.cj` — 每个类型类别一个。当前 iterator 表面完全无覆盖。

### 模板

参照 `vector_int32_abi_test.cj` 的结构：一个自定义 `_Impl` 类经 `createComObjectFromSchemas` 串起，helper 函数构造投影接口，`@Test` 同时验证投影 wrapper 和直接 vtable 调用。

### 维护

- 新增一个测试 → 更新表中对应单元格，并从"推荐顺序"中划除。
- 出现新类别 → 扩表，每个类别只加一个代表测试，覆盖 ABI 形态而非 API 表面。

## 完成标准

一个批次只有满足以下条件才可以提交：

- 测试在修复前失败，或静态审计证明存在真实风险。
- 系统性行为必须优先修在共享 helper 或生成器里。
- `cjpm` 编译检查和相关 `cjv exec` 测试二进制通过。
- `python scripts/check_workspace_setup.py` 和 `git diff --check` 通过。
- review agent 报告没有 P0/P1/P2 问题。

达到生产质量需要满足：

- 不变量清单都有自动测试或静态审计覆盖。
- 真实 Windows smoke 测试在受支持的 Windows 机器上通过。
- 每个 active package 都有 readiness 状态，且没有开放的 P0/P1/P2 ABI/生命周期风险。
