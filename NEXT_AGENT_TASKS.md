# windows-cj 生产质量任务

创建时间：2026-05-15 14:24 +08:00

本文档取代之前的滚动对齐日志。旧日志已经删除，因为它更像长会话流水账，存在过时的 round/review 顺序信息，不再适合作为下一任 agent 的执行入口。历史细节仍可通过 git 历史查看。

## 当前基线

- 最近已知提交基线：`58c8770c fix: clean replaced abi arrays`。
- 不要直接恢复已放弃的未提交 Round140 代码。
- `AbiArray<HString>.get()` 所有权候选问题已结案：`windows-core/src/abi_array_test.cj` 固化了 get 返回独立 owned wrapper、replaceWith 先 clone 再 clear 的契约；`windows-core` 单包验证通过。
- 2026-05-19 收尾基线：两轮 8 小时 bugfix 已完成；逻辑修复后的 full workspace tests 与 full quality gate 均通过，后续 EOF/hash 收尾由轻量门禁和 quick codegen 覆盖。详细流水见 `AGENT_TIMELOG_2026-05-19.md`。

## 目标

通过证明并强制执行 ABI、所有权、生成 wrapper 的不变量，让 `windows-cj` 达到生产质量。

目标是以 `ref/windows-rs` 为行为参考，实现 Win32/WinRT ABI 行为等价；不是逐字匹配 API 形态。不要引入不适合仓颉的外部语言概念。优先使用仓颉范式：`Resource.close()`、显式资源释放责任 wrapper、单类型特化代码生成、共享 helper API。

这里的“资源释放责任”不是 Rust 的借用/生命周期/所有权类型系统。它只表示某个仓颉对象负责在确定时机调用外部资源的释放 API，例如 COM `Release`、HSTRING 删除或 `CoTaskMemFree`；仓颉对象之间的普通引用仍由 GC 管理。

## 硬性规则

- 编辑仓颉代码前，必须通过 Cangjie MCP 查询官方文档，确认本次编辑会用到的语法/API。
- 运行任何 `cjpm` 命令前必须设置 `cjHeapSize=32GB`。
- 执行仓颉编译产物必须使用 `cjv exec <binary>`，不得直接运行二进制。
- `windows-runtime` 单测不要用仓颉 unittest 的 `--timeout-each` 做超时控制；Windows worker timeout 路径可能在运行时 shutdown 中挂住。使用 `python scripts/run_windows_runtime_tests.py` 的外层进程树 watchdog；带 `--filter` 时 runner 会拒绝 0-test false green。
- 全 workspace 验证不要直接使用根目录 `cjpm test` 聚合 runner 作为唯一信号。根 runner 会通过 std.testrunner worker 协议运行 `windows_runtime.exe`，Windows 上可能在测试体完成后不退出；使用 `python scripts/run_windows_workspace_tests.py`，它先 `cjpm test -m <member> --no-run` 编译，再通过 `cjv exec` + `--progress-brief` 直接执行测试二进制。
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
- 析构器 `~init()` 不得直接或间接使用 `synchronized` / `lock` / `unlock`，也不得调用动态符号解析、native free/close、COM `Release` 或可能等待外部 callback 的清理 API。仓颉 finalizer thread 没有可 park 的 cjthread，上述路径会触发 runtime fatal 并导致测试进程不退出；native 资源释放必须走显式 `Resource.close()`，finalizer 只能做本对象内的 closed/raw-slot 标记。

## 工作计划

### 1. 建立静态审计门禁

创建或扩展 Python 检查，覆盖高风险模式：

- ✅ `fromAbiTake` 路径可能接受 null owned pointer。（`scripts/check_abi_ownership.py` 审计 owned COM `fromAbiTake(raw)` 必须走共享 takeOwnership guard。）
- ✅ `QueryInterface` 结果没有被 `try`/`close` 包住，也没有返回给调用方。（`scripts/check_abi_ownership.py` 审计 helper 返回的 `Some(raw)` 必须返回/包装或确定性释放，直接 vtable `QueryInterface` 仅允许窄白名单 helper。）
- `HRESULT(...).ok()` 的结果被忽略。
- ✅ `CoTaskMemAlloc` 或 raw HSTRING slot materialization 缺少失败清理。（`scripts/check_workspace_setup.py` 审计核心 array/raw-slot materializer 的失败清理路径。）
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

状态定义：

- **Production-ready**：核心 ABI/所有权不变量有自动测试或静态审计覆盖；当前无开放 P0/P1/P2；下一步只剩工具改进。
- **Subset-ready**：当前 checked-in 子集有静态/生成门禁覆盖，但不能代表完整 `windows` 包已经交付。
- **Candidate**：测试覆盖核心 ABI 路径但还缺真实 Windows smoke 或类型类别完成度；无活跃 P0/P1。
- **Needs tests**：编译通过但单元覆盖明显不足；P0/P1 可能潜伏未发现。
- **Blocked**：依赖未交付或上游约束未解。
- **Not active**：不是当前 workspace member，不作为构建或 readiness 目标。

最近一次账本刷新：2026-05-19（两轮 bugfix 后刷新 readiness 与测试数量；`windows-propvariant`、`windows-safearray` 已进入根 workspace，并纳入 `scripts/check_workspace_setup.py` active member / dependency gate 覆盖）。

收尾验证：2026-05-19 19:10 +08:00 已完成逻辑修复后的 full workspace test pass，所有 active test members 均通过；随后 `python scripts\run_windows_quality_gate.py --mode full --workspace-timeout-seconds 480 --codegen-timeout-seconds 600` 通过 full codegen、全部 workspace tests 和 macro fixtures。2026-05-19 收尾阶段又做了 generated EOF / LF-normalized manifest hash 修正，并补跑 `git diff --check`、changed Python gate scripts 的 `py_compile`、`python scripts\check_workspace_setup.py`、以及 `$env:cjHeapSize='32GB'; python scripts\check_windows_common_codegen.py --mode quick --timeout-seconds 600`，均通过。

本轮门禁刷新：2026-05-18（`scripts/check_workspace_setup.py` 已通过 active workspace member / dependency / generated-output invariant gate；`scripts/check_windows_common_codegen.py --mode quick` 已通过 manifest file_hashes、`.generated/winmd-json` 顶层 `winmd_file`/`winmd_sha256` 对真实 `winmd/*.winmd` 的 checksum、以及 `windows-common` 编译入口；`scripts/check_windows_common_codegen.py --mode full` 已通过当前可用 Windows/Win32/Wdk metadata 子集再生成与 checked-in `windows-common` diff。旧的可用子集 diff 已关闭：MsXml extra、DEVPROPKEY/PROPERTYKEY/BINDINFO GUID layout、SetLastError BOOL checked helper、Com/Ole/Threading vtbl alias 不再列入 blocker。当前仓库只有 Windows/Win32/Wdk winmd-json，仓库内没有已转换的 `Microsoft.UI.*` JSON；本机 NuGet cache 可作为外部 WinUI/WindowsAppSDK `.winmd` 来源，但 gate 和转换 helper 都默认不自动消费本机 cache，因此缺 converted WinUI JSON 时 10 个 `Microsoft.UI.Xaml.*` requested feature 仍明确记录为 blocked/skipped。worker BB 新增 `scripts/convert_winmd_to_json.py`，支持显式 `--winmd-root` 到 JSON 目录转换、`--dry-run` 和 `--list-candidates`，并让 gate 错误提示引用该 helper。带 WinUI 的 full gate 需要通过 `--winui-winmd-json-dir` / `WINDOWS_CJ_WINUI_WINMD_JSON_DIRS` 加入 helper 产出的 JSON，并用 `--winui-winmd-root` / `WINDOWS_CJ_WINUI_WINMD_ROOTS` 校验对应原始 `.winmd` hash。）

本机 WinUI metadata gate 评估：2026-05-18（worker 3 只读优先验证 helper。候选发现命令：`python .\scripts\convert_winmd_to_json.py --list-candidates --candidate-limit 50`。最新本机 WindowsAppSDK roots 为 `%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk\1.4.231219000\lib\uap10.0` 和 `...\lib\uap10.0.18362`；转换命令：`python .\scripts\convert_winmd_to_json.py --winmd-root $rootA --winmd-root $rootB --json-dir $jsonDir --overwrite --timeout-seconds 300`，临时目录内 17 个 `.winmd` 成功生成 57 个 JSON。验证命令：`python .\scripts\check_windows_common_codegen.py --mode full --skip-build --winui-winmd-json-dir $jsonDir --winui-winmd-root $rootA --winui-winmd-root $rootB --timeout-seconds 300`。结果：不能在本机完整跑通 checked-in parity；metadata hash 校验通过（739 个 JSON、包含 17 个 WinUI/WindowsAppSDK source 和默认 Windows/Win32/Wdk source），`cjpm build -m windows-bindgen` 通过，但带 WinUI 再生成后 manifest 的 `selected_symbols` / `files` / `file_hashes` 与 checked-in `windows-common` 不一致。临时再生成统计：checked-in 1603 selected symbols / 136 files；本机 WindowsAppSDK 1.4 再生成 2222 selected symbols / 157 files，新增 626 symbols 和 21 files，且缺少 checked-in 里的 `Microsoft.UI.Xaml.DispatcherShutdownMode`、`Microsoft.UI.Xaml.IApplication3`、`Microsoft.UI.Xaml.IDebugSettings3`、`Microsoft.UI.Xaml.IXamlRoot3`、`Microsoft.UI.Xaml.IXamlRoot4`、`Microsoft.UI.Xaml.LayoutCycleDebugBreakLevel`、`Microsoft.UI.Xaml.LayoutCycleTracingLevel`。这些 7 个 symbols 在本机 `Microsoft.WindowsAppSDK` 1.1.0..1.4.231219000 与 `Microsoft.UI.Xaml` 2.0/2.5/2.8 candidate 转换后的 `Microsoft.UI.Xaml.winmd` JSON 中均未出现。单独使用 `%USERPROFILE%\.nuget\packages\microsoft.ui.xaml\2.8.2-prerelease.220830001\lib\uap10.0` 可转换 1 个 `.winmd` 为 8 个 JSON，但 full gate 在 generator 阶段失败：`unknown feature: Microsoft.UI.Xaml.Application`。下一步需要获取与 checked-in WinUI surface 匹配的 WinUI/WindowsAppSDK metadata，或明确重定当前 `windows-common` WinUI selected subset；不要提交临时 WinUI JSON。）

本轮交付面审计更正：2026-05-18（当前 root workspace member 是 `windows-bindgen`，不是旧的 `windows-cj/windows`；`windows-cj/windows-bindgen/cjpm.toml` 的 package name 是 `windows_bindgen`，用户 CLI 名称记录为 `windows-bindgen`。WinMD reader 只有 C#/.NET `winmd-to-json` converter；Cangjie bindgen 只消费 converter 产出的 JSON，不计划实现 native Cangjie `.winmd` reader。当前 root workspace 不再包含 `windows-sys` / `windows_sys`。由于仓颉编译速度约束，full raw sys package 不再作为交付目标；需要 Win32/WinRT ABI surface 时，优先通过 selected generated/common support、明确 feature set 和 manifest gate 扩展。`windows_projection` 仍只是消费侧 scaffold，checked-in 可导入生成面仍主要是 `windows-common` / `windows_common`，manifest 为 19 个 requested features、1603 个 selected symbols、136 个 generated files。）

上一轮质量刷新：2026-05-16（runtime finalizer-thread park 修复、长期 vtable/slot 存储改为 unmanaged native allocation、真实 WinRT smoke、ABI ownership 审计、`ComObject.intoInterface` 消费 owner 引用后，`windows-runtime` 163 tests passed，0 failed；WinUI3 `Application.Start` delegate ABI 改为真实 COM delegate object，`windows-cj-demo` smoke 已进入 callback 并输出 `Window activated`；按 member 直接执行 workspace 验证合计 463 passed，0 failed；`python windows-interface/scripts/check_macros.py` 约 12s 完成）。

| Package | 状态 | 测试数 | 关键不变量覆盖 | 下一步 |
| --- | --- | --- | --- | --- |
| `windows-libloading` | Production-ready | 13 | System32-only / explicit search-path 双策略；DLL 缓存；path-like 模块名拒绝；ordinal 范围校验；public uncached byte inputs 必须 NUL 终止 | — |
| `windows-result` | Production-ready | 21 | HRESULT / NTSTATUS / RPC_STATUS / WIN32_ERROR `.ok()`/`.unwrap()`/`.check()` 三栏；公开符号 surface；error-info BSTR / QueryInterface failed-output cleanup | — |
| `windows-strings` | Production-ready | 11 | HSTRING handle 生命周期、ref-backed vs alloc-backed clone、BSTR `fromRaw*` 视图；lossy UTF-8 trailing incomplete sequence emits replacement char | smoke：WindowsCreateString / DeleteString 真实调用 |
| `windows-result` internal BSTR helper / `windows-strings.BSTR` | Production-ready | — | 公开/生成 Win32 BSTR 统一映射到 `windows_strings.BSTR`；`windows-result.BasicString` 仅为内部 error-info helper，显式 `close()` 释放，finalizer 不跑 native free | — |
| `windows-interface` | Production-ready | 19 | Macro 生成 vtable 形态；descriptor 基础约束；继承链覆盖 fixture；manual wrapper `release()` / `intoAbi()` re-entrant ownership | — |
| `windows-implement` | Production-ready | 30 | Schema vtable resolution、深继承 slot 数、QI ancestor fallback、custom vtable 必填；descriptor/composable/weak-reference failed-output cleanup | smoke：真实 ComObject 注册 / WinRT activation |
| `windows-core` | Production-ready | 57 | AbiArray owned semantics（红测固化）、HString winrt out/in 边界、null owned 拒绝、generic factory borrow view；WinRT generic out range / QueryInterface / marshaler / factory failed-output cleanup | — |
| `windows-polyfill` | Production-ready | 60 | factory_cache、reflective COM 接入、polyfill 形态 | — |
| `windows-runtime` | Production-ready | 197 | Vector/VectorView/Map/MapView/Iterator/Array scalar + copy struct + HString + COM interface 代表 ABI；async finish/cancel/fail；collection null-buffer guard；GetMany / Split / PropertyValue array failed-output cleanup；真实 WinRT activation / PropertyValue array / Uri decoder smoke | 工具：继续扩展静态审计 |
| `windows-threading` | Production-ready | 6 | submit / submitDefault / closeInternal；真实 Windows threadpool submit/forEach/withScope smoke；裸 Pool 使用由静态审计要求显式 close 或 withScope | — |
| `windows-version` | Production-ready | 3 | 版本字符串解析；OS 包装 ABI 类型；当前系统版本 smoke | — |
| `windows-numerics` | Production-ready | 9 | Vector2/Vector3/Vector4 与 Matrix3x2/Matrix4x4 构造、算术、比较和投影 helper | — |
| `windows-variant` | Candidate | 13 | VARIANT scalar/BSTR/raw pointer payload roundtrip；`Variant` Resource clone/clear 路径；failed native cleanup preserves ownership for retry；re-entrant clear guard | smoke：真实 COM VARIANT interop |
| `windows-propvariant` | Candidate | 17 | PROPVARIANT scalar、FILETIME、CLSID、blob、LPSTR/LPWSTR、BSTR、raw COM pointer payload；`PropVariant` Resource clone/clear 路径；re-entrant clear guard | smoke：真实 shell property API roundtrip |
| `windows-safearray` | Candidate | 23 | SAFEARRAY create/destroy/lock/access；I4/R8/BSTR/VARIANT typed arrays；ownership transfer 和 descriptor deep copy；clone partial-output destroy；re-entrant destroy guard | smoke：真实 COM SAFEARRAY consumer/provider roundtrip |
| `windows-targets` | Production-ready | 2 | 链接 target 选择；bundled GNU archive 元数据；`check_workspace_setup.py` 校验 archive 名称、存在性和非空 payload；当前 active payload 仅 `x86_64_gnu`，其它 target 明确 unsupported/no bundled payload | — |
| `windows-registry` | Production-ready | 12 | 字节↔宽字符转换、ABI types 委托给 windows-common；真实 HKCU volatile key roundtrip smoke；Key/Transaction re-entrant native close guard | — |
| `windows-services` | Production-ready | 8 | dispatch / 状态守护 synchronized 块；dispatcher failure smoke；fallback path 覆盖 start/stop 状态序列；`Service.run()` finally unregisters active service id | 可选：单独的管理员/服务宿主集成 harness，不作为常规单测门禁 |
| `windows-common` | Subset-ready | 0 (generated) | 由 `check_workspace_setup.py` 强校验：DO NOT EDIT 头、SHA256 哈希、WinUI3 delegate raw COM pointer、delegate `HandleWinrtType`、依赖闭包；`check_windows_common_codegen.py --mode quick` 覆盖真实 WinMD JSON checksum 与编译入口；full 对当前可用 Windows/Win32/Wdk metadata 子集再生成并 diff，当前可用子集无剩余 diff；WinUI feature 在缺 metadata 时明确 blocked/skipped；`scripts/convert_winmd_to_json.py` 可将显式 WinUI/WindowsAppSDK `.winmd` root 转为 JSON 并通过 hash gate，但本机 WindowsAppSDK 1.4 / Microsoft.UI.Xaml 2.x metadata 尚不能重现 checked-in WinUI parity（见上方 worker 3 记录）。注意：这是 `windows_common` selected subset，不是完整 high-level `windows` 包；当前 workspace 没有 `windows_sys` / `windows-sys`，full raw sys package 因仓颉编译速度约束不再作为交付目标 | 获取与 checked-in WinUI surface 匹配的 WinUI/WindowsAppSDK metadata，或明确重定 `windows-common` WinUI selected subset；设计 full projection package / selected generated/common support / feature slicing；继续使用 `winmd-to-json` 作为唯一 WinMD reader |
| `windows-winui3` | Production-ready | 14 | XAML / Markup / Controls 手写 helper；HSTRING 输入借用；`Application.Start` 真实 WinRT delegate COM object；manual helper failed out-slot cleanup for CreateInstance / FindName / Load | — |
| `windows-projection` | Subset-ready | 2 (scaffold import smoke) | `windows_projection` scaffold 可导入 checked-in `windows_common`，并暴露 tiny `windows_projection.Win32.Foundation` 与 `windows_projection.Win32.System.Threading` facade；它不是 full consumer `windows` projection package | 明确保留 `windows_projection` 作为消费包名或另行设计 full projection package 后，扩展 projection surface 与 feature slicing |
| `windows-sys` / `windows_sys` | Not active | — | 当前 root workspace 不包含该 package。仓颉编译速度使 full raw sys package 成为错误交付面；不要把它作为 active readiness 目标 | 如需 Win32/WinRT ABI surface，扩展 selected generated/common support，并让 manifest/gate 覆盖明确 feature set |
| `windows-bindgen` (generator CLI) | Production-ready | 187 | 目录 `windows-cj/windows-bindgen`，package name `windows_bindgen`，用户 CLI 名称记录为 `windows-bindgen`；render_symbol / interface / runtime class / collection thunk 模板；generated native helper checked wrappers；generic aliases；raw handle/delegate `Resource` wrappers；manifest file_hashes；`--input-dir`；生成文件 EOF 规范化。注意：该 package 是 executable generator，不是用户可依赖的 high-level `windows` projection package；它只消费 JSON，WinMD reader 是 C#/.NET `winmd-to-json` | 后续若要交付 full `windows` 包，应与 `windows-bindgen` 保持命名和职责边界清晰 |

不变量覆盖（向量化清单）：

- ✅ owned ABI 拒绝 null owned pointer：`windows-core` 静态规则 + 集合 buffer guard。
- ✅ HSTRING 唯一释放方：`windows-strings` + `windows-core` ABI 边界 + AbiArray.get() owned clone。
- ✅ HRESULT 失败不被静默 `.ok()` 吞：`scripts/check_ignored_results.py` 审计。
- ✅ `Resource.close()` 与 finalizer closed/raw-slot 标记防 double free：`windows-core` / `windows-runtime` impl 测试；native 释放责任在 `close()`，finalizer 不再执行 native cleanup；`scripts/check_workspace_setup.py` 要求持有 `allocateNativeValue`/`allocateNativeArray` 的 class 具备 `Resource.close()`、refcount destroy 或 runtime onDestroy 释放路径。
- ✅ finalizer 不阻塞：`scripts/check_workspace_setup.py` 扫描所有 active `.cj` 的 `~init()`，拒绝直接 `synchronized` / `lock` / `unlock`，并拒绝已知间接 native/COM cleanup helper（如 `release*NoThrow`、`destroySafeArrayNoThrow`、`closeRegistryKey*`、`closeHString*`、`releaseOwnedComPointer`、动态 `resolveProc`、HSTRING/BSTR/native free、COM registry `releaseBase`、registry/threadpool cleanup wait）；普通 `Resource.close()` 中的 helper cleanup 仍允许。
- ✅ 临时 `ComObject` 投影不会泄漏 owner 初始引用：`ComObject.intoInterface` 投影成功后立即 `close()` owner，返回的 owned interface 持有唯一活引用；`scripts/check_workspace_setup.py` 拒绝生产代码用临时 `ComObject` `toInterface()` 后忘记 `close()` / `releaseBase()`。
- ✅ 真实 Windows smoke：`windows_runtime_smoke_test.cj` 覆盖 activation factory 失败路径、`PropertyValue.CreateInt32Array` roundtrip、`Uri` / `WwwFormUrlDecoder` HSTRING 与集合投影 roundtrip。
- ✅ generated vtable thunk 非零容量 null buffer guard：`windows-runtime/collection_null_buffer_thunk_test.cj` 与 vector/vector view/iterator direct ABI 测试覆盖代表类型类别。
- ✅ owned QueryInterface 结果确定性关闭：`scripts/check_abi_ownership.py` 自动审计 `queryInterfaceRaw` / `queryInterfaceAs` / `comQueryInterfaceRaw` 的 `Some(raw)` 消费路径。
- ✅ array/raw-slot 部分失败清理：`scripts/check_workspace_setup.py` 审计 `AbiArray`、`ArrayProxy`、generic WinRT handle arrays、PropertyValue HSTRING/interface array materializer，要求失败路径释放已接管元素、剩余 raw slot 和 CoTaskMem buffers。
- ✅ WinRT delegate ABI：生成器将 WinRT delegate 参数渲染为 COM pointer / raw handle class，raw handle class 实现 `HandleWinrtType`；`windows-winui3` 为 `ApplicationInitializationCallback` 构造 IUnknown-based COM object，demo smoke 已验证 `Application.Start` 回调进入并激活窗口。
- ✅ failed-HRESULT partial output cleanup：client wrappers、producer thunks、generated descriptor/runtime wrappers、WinUI helpers、BSTR/HSTRING/COM/interface/SAFEARRAY paths 均有代表测试或静态审计覆盖，失败前清 slot 并释放已接管资源。
- ✅ generated raw handle ownership：生成 raw COM/interface handle wrappers 实现 `Resource`，区分 owned/borrowed handles，并用 workspace invariant 拒绝缺少 `Resource` 的 stale raw wrappers。
- ✅ stale caller slot 防护：GetMany、Split、PropertyValue array、descriptor producer 和 QueryInterface fallback 路径在 dispatch 前清 out slots / result counts，避免 no-write failure 释放调用方旧值。

后续工具改进（非阻塞）：继续扩展静态审计到更多生成 wrapper 边界；`CoTaskMemAlloc` / raw HSTRING slot materialization 失败清理、out-parameter array 部分 materialize 失败清理已由 `scripts/check_workspace_setup.py` 的 array materialization cleanup 门禁覆盖。剩余产品化 blocker 是 WinUI metadata parity、`windows-variant`/`windows-propvariant`/`windows-safearray` 真实 Windows smoke，以及 full projection package / selected generated support 的交付边界。

## 交付收尾状态

- 2026-05-19：两轮 8 小时 bugfix 目标已完成，最终验证通过；后续 heartbeat 自动化已删除。
- 轻量收尾检查通过：`git diff --check`、changed Python gate scripts 的 `py_compile`、`python scripts\check_workspace_setup.py`、`$env:cjHeapSize='32GB'; python scripts\check_windows_common_codegen.py --mode quick --timeout-seconds 600`。
- 建议提交拆分：quality gate scripts；core/runtime/implement/interface ownership fixes；generator 与 `windows-common` 同步；targeted package fixes（WinUI/libloading/services/strings/variant/propvariant/safearray/registry/result）；timelog/readiness docs。
- 不建议直接开启第三轮盲修。下一项工程任务应从明确 blocker 中选择：WinUI metadata parity、真实 COM smoke、或 projection/package boundary。

## 已完成批次记录

1. ~~确认 worktree 除本文档新增和旧日志删除外没有其他变更。~~（已完成）
2. ~~跑基线验证。~~（已完成）
3. ~~重新评估 `AbiArray<HString>.get()` 所有权候选问题。~~（已修，提交 `ba017c29`：`ProjectedAbiArrayStorage.get()` 现在返回独立 owned clone；红测固化契约。）
4. ~~添加第一条静态审计检查。~~（已完成，提交 `1846e803`：`scripts/check_ignored_results.py` 检测忽略的 `Result.ok()`，由 `check_workspace_setup.py` 调用。已记录的盲点：if/else 分支末尾、match 分支末尾。）
5. ~~启动 array 和 collection thunk 的类型类别测试矩阵。~~（已完成；见下文"类型类别测试矩阵"小节。）

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
| Vector | ✅ `vector_int32_abi_test.cj` 等每个标量宽度一个 | ✅ `vector_copy_struct_abi_test.cj`, `vector_datetime_abi_test.cj` | ✅ `vector_hstring_abi_test.cj` | ✅ `vector_interface_abi_test.cj` |
| Vector view | ✅ `vector_view_uint8_abi_test.cj` 等 | ✅ `vector_copy_struct_abi_test.cj`, `vector_datetime_abi_test.cj` | ✅ `vector_view_hstring_abi_test.cj` | ✅ `vector_view_interface_abi_test.cj` |
| Map | ✅ `map_int32_abi_test.cj` 等 | ✅ `map_int32_datetime_abi_test.cj` | ✅ `map_int32_hstring_abi_test.cj`, `map_uint32_hstring_abi_test.cj`, `map_hstring_int32_abi_test.cj` | ✅ `map_int32_interface_abi_test.cj` |
| Map view | ✅ `map_view_int32_generic_abi_test.cj`, `map_uint32_abi_test.cj` | ✅ `map_int32_datetime_abi_test.cj` | ✅ `map_hstring_int32_abi_test.cj` | ✅ `map_int32_vector_view_abi_test.cj`, `map_int32_interface_abi_test.cj` |
| Iterator | ✅ `iterator_abi_test.cj` | ✅ `iterator_abi_test.cj` | ✅ `iterator_abi_test.cj` | ✅ `iterator_abi_test.cj` |
| Array (in/out/replace) | ✅ `vector_int32_generic_abi_test.cj`, `property_value_array_abi_test.cj` | ✅ `vector_datetime_abi_test.cj`, `property_value_array_overload_test.cj`, `property_value_get_array_overload_test.cj` | ✅ `vector_hstring_abi_test.cj`, `vector_view_hstring_abi_test.cj`, `property_value_array_overload_test.cj` | ✅ `vector_interface_abi_test.cj`, `vector_view_interface_abi_test.cj`, `property_value_array_overload_test.cj` |

### 推荐顺序

1. ~~`vector_hstring_abi_test.cj`~~（已完成）：直接走泛型 `IVectorVtbl.new<Identity, HString>` + `IIterableVtbl.new<Identity, HString>`。覆盖 wrapper 路径（SetAt/InsertAt/Append/IndexOf）和直接 vtable 路径（HSTRING raw handle in/out，含 GetAt out-slot）。
2. ~~`vector_interface_abi_test.cj`~~（已完成）：`IVector<IInspectable>` 覆盖 wrapper 路径和直接 vtable 路径，包含 borrowed input、owned output、`GetMany` out buffer、`ReplaceAll` input buffer、null handle 拒绝。
3. ~~`vector_view_hstring_abi_test.cj`~~（已完成）：`IVectorView<HString>` 覆盖 wrapper 路径和直接 vtable 路径，包含 raw HSTRING input、owned HSTRING output、`GetMany` out buffer、非零容量 null buffer guard。
4. ~~`vector_view_interface_abi_test.cj`~~（已完成）：`IVectorView<IInspectable>` 覆盖 wrapper 路径和直接 vtable 路径，包含 borrowed interface input、owned interface output、`GetMany` out buffer、非零容量 null buffer guard。
5. ~~`map_hstring_int32_abi_test.cj`~~（已完成）：`IMapView<HString, Int32>` 和 `IMap<HString, Int32>` 覆盖 HString key handle ABI，包含 raw HSTRING input、owned HSTRING output、`HasKey`、`Insert` 替换路径和直接 vtable 路径。
6. ~~`iterator_abi_test.cj`~~（已完成）：`IIterator<T>` 覆盖 copy scalar、projected copy struct、HString handle、COM interface handle，包含 wrapper 路径、直接 vtable `Current`/`GetMany`、cursor advance、非零容量 null buffer guard。
7. ~~`map_int32_interface_abi_test.cj`~~（已完成）：`IMapView<Int32, IInspectable>` 和 `IMap<Int32, IInspectable>` 覆盖 COM interface value handle ABI，修复 generic vtable/wrapper 对 Int32 key + IInspectable value 的直接 ABI 分派。
8. ~~`map_int32_datetime_abi_test.cj`~~（已完成）：`IMapView<Int32, DateTime>` 和 `IMap<Int32, DateTime>` 覆盖 projected copy struct value direct ABI，修复 generic vtable/wrapper 对 Int32 key + DateTime value 的直接 ABI 分派。
9. ~~array in/out/replace 代表覆盖~~（已完成）：`vector_int32_generic_abi_test.cj`、`vector_datetime_abi_test.cj`、`vector_hstring_abi_test.cj`、`vector_interface_abi_test.cj` 覆盖 direct vtable `GetMany`/`ReplaceAll` 的 scalar、copy struct、HSTRING、COM interface 数组 ABI；PropertyValue array overload 测试覆盖真实属性数组桥接。

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
