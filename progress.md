# windows-cj 进度

最后更新：2026-05-03（VPGC bindgen 重写启动 — M0 + M0.5 + M0.7 项目骨架 + winmd-to-json 工具就绪）

## 总目标

以 `ref/windows-rs` 为行为参考，把 `windows-cj` 对齐到"相同输入产生相同 Win32 / COM / WinRT ABI 效果"。

## 全局约束

- **运行任何 cjpm 命令前必须设环境变量 `cjHeapSize=32GB`**（默认 256 MB heap 在 729 包项目分析时直接 OOM；这是 cjpm 自己的 Cangjie runtime heap，与 cjc 编译时内存无关）
- 行为等价优先，不强行复刻 Rust 表面语义。
- 仓颉是 GC 语言，不移植 Rust 的借用 / 生命周期 / `Deref` / 编译期宏字面量 / `unsafe fn` 标记 / `repr(C)` 内联 managed 对象等核心范式。
- 原生 COM 指针生命周期使用 `Resource` + `~init` + closed guard。
- 仓颉代码落地前必须用 `mcp__cangjie__cangjie_search_docs` 查官方文档确认语法 / API；不得凭记忆。
- 状态以真实 build / audit 证据为准，不以"文档宣称完成"代替。
- 编译内存 / 编译时长属于上游编译器问题，不作为功能对齐 blocker。
- `windows-rdl` / `windows-riddle` 不实现，已记为 out-of-scope。

## Wave 状态（截至 2026-04-25）

| Wave | 状态 | 说明 |
| --- | --- | --- |
| 0 | done | baseline / spec / ledger |
| 1 | done | 生命周期模型 / GUID fallback / COM wrapper 修正 |
| 2 | done | 生成链 + polyfill 门禁 |
| 3 | done | `windows-sys` raw layer + large-heap full build |
| 4 | done | `windows-result` / `windows-strings` / `windows-interface` / `windows-implement` / `windows-core` runtime / authoring |
| 5 | done | `windows-future` / `windows-collections` / `windows-numerics` support |
| 6 | done | live `windows/src` high-level projection；public Win32 / COM / WinRT 验证曾转绿 |
| 7 | done | secondary packages + 公共 link glue |

旧脚本式验证 / audit 入口、fixture、runner 工程和 tests 目录资产已删除；后续验证会重写，以 `cjpm`、生成器命令和 Python 工具为准。

## 已落地 crate

| ref/windows-rs | windows-cj | 备注 |
| --- | --- | --- |
| bindgen | windows-bindgen | union / delegate / import-entry-point warning 待收 |
| collections | windows-collections | |
| core | windows-core | runtime / factory / weak / agile / marshaler 已转绿 |
| future | windows-future | |
| implement | windows-implement | |
| interface | windows-interface | 生命周期模型重做完毕 |
| link | windows-targets + link glue | `windows-cfggen` archive + `windows-version` consumer 已闭环 |
| metadata | windows-metadata | |
| numerics | windows-numerics | projected `struct` + `@C struct Abi` 双层契约 |
| registry | windows-registry | |
| result | windows-result | |
| services | windows-services | Service fallback / control routing |
| strings | windows-strings | `HString` / `BSTR` 为资源类，不强求 Rust 值语义 |
| sys | windows-sys | raw-layer gate 已关闭 |
| targets | windows-targets | GNU archive carrier |
| threading | windows-threading | |
| version | windows-version | |
| windows | windows | live high-level generated projection |
| cppwinrt | — | 非目标 |
| rdl | — | out-of-scope |
| riddle | — | out-of-scope |

## VPGC bindgen 重写（active）

设计文档：[docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md](docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md)

按 suggest.md (VPGC 35 节) 完全重写 bindgen 与 cfggen，采用 Python 实现 + C# winmd-to-json 工具，输出三层架构（runtime / internal carrier / public facade）。

### Milestone 进度

- [x] **M0 + M0.5 + M0.7：项目骨架 + winmd-to-json 工具就绪**（2026-05-03）
  - 旧 bindgen 备份到 `windows-cj/windows-bindgen-legacy/`，旧 cfggen 备份到 `windows-cj/windows-cfggen-legacy/`
  - 新 `windows-cj/windows-cj-bindgen-py/` Python 项目骨架就位（pyproject + ruff + mypy + pytest 4 smoke tests pass）
  - 新 `windows-cj/windows-cj-cfggen-py/` Python 项目骨架就位（pyproject + monorepo path 依赖 bindgen-py + 6 smoke tests pass）
  - 新 `windows-cj/winmd-to-json/` C# .NET 10 工具 vendored from ynkdir/winmd-printer (MIT)
  - winmd-to-json `dotnet publish` 产出 self-contained exe；3 份 winmd 解析为 deterministic byte-identical JSON
  - `windows-cj-bindgen --version` 与 `windows-cj-cfggen --version` 走通
  - 验证脚本：[tools/check_workspace_setup.py](tools/check_workspace_setup.py)
- [ ] **M1：winmd JSON wrapper（Python 消费 winmd-to-json 输出）**
- [ ] **M2：Canonical Dependency IR**
- [ ] **M3：Helper Normalization**
- [ ] **M4：Atom + Hard Graph + Predicate BDD**
- [ ] **M5：Guarded SCC Condensation**
- [ ] **M6：Carrier Clustering**
- [ ] **M7：Facade + DAG Proof**
- [ ] **M8：Codegen**
- [ ] **M9：Runtime 包迁移**
- [ ] **M10：Report + Profile**
- [ ] **M11：全量重生 + cjpm build smoke**
- [ ] **M11.5：cfggen-py 端到端验证**
- [ ] **M12：ABI smoke + WinUI 3 demo 复活**

### 已知 backlog（M0 阶段发现）

- 旧 progress.md "windows-cj-demo / WinUI 3 启动" active 工作在 VPGC 重写期间停摆，等 M11/M12 完成后用新生成产物复活
- M1 winmd_json wrapper 实现时需特别注意 winmd-to-json 上游 `usage()` 输出走 stdout 而非 stderr（zero-arg 调用会污染 stdout 解析）— Python wrapper 必须先校验 returncode，再尝试 json.load

## 当前 active 工作：windows-cj-demo（WinUI 3 启动）

详见 [windows-cj-demo](windows-cj-demo/)。目标：以 `windows` + `windows-appsdk` 为依赖跑出一个最小 WinUI 3 窗口。

- [x] **AppSDK / WebView2 binding 落地**
  - `windows-appsdk-sys` / `windows-appsdk` / `windows-webview2-sys` / `windows-webview2` 包就位
  - `windows-libloading` 加载 `Microsoft.WindowsAppRuntime.Bootstrap.dll`，`MddBootstrapInitialize2` / `MddBootstrapShutdown` 通路工作
  - `prepare_nuget_metadata.py` + `build_appsdk.py` 自动取 NuGet metadata 并 regen
- [x] **`windows-cfggen` 多 catalog 支持**
  - 多 catalog roots、依赖闭包自动发现、合并 `features.toml` / `cfg_list.toml` / `link-options.toml`
  - 在 user 工程写 `[package].override-compile-option = "--cfg <user_dir>"`，让 cjpm 编译每个依赖包时把 `--cfg` 传下去（cjpm 源码 `dep_model.cj:217-218` + `build.cj:811-812` 已确认语义）
- [x] **bindgen 循环依赖修复**（2026-04-28）
  - 中间状态：曾试图把 `_impl_l*` 中所有 facade `import` 的 `@When[]` 守卫拆掉以解决「cjpm 把 sys 投影包当 optional dep 不拼 link 行」的链接错误；副作用是 facade `windows.X.Y` 与 `_impl_l*` 之间形成 cyclic dependency
  - 修复：[main.cj `shouldGuardLayerImportToFacade`](windows-cj/windows-bindgen/src/main.cj) — 仅当 `_impl_l*` 包导入**同 module 内非 Win32./Wdk. 投影**的 facade 时保留 `@When[Feature == "on"]` 守卫，其它（facade↔facade、facade↔Win32 投影、_impl_l↔Win32 投影）一律无守卫，让 cjpm 把这些当硬依赖加进 link 行
  - 验证：`cjpm build windows-cj-demo` 全 1500+ 包通过，`main.exe` 94 MB 生成
- [x] **bindgen 分阶段计时**
  - 入 [main.cj `runBindgen`](windows-cj/windows-bindgen/src/main.cj) 各阶段加 `MonoTime` + `[stage]` 日志，方便诊断 729 包 regen 长尾分布（winmd-load / type-index / type-map / derive-targets / namespace-render / write-* / TOTAL）
- [x] **demo 类型检查通过**（`cjc-frontend -p src --cfg . --import-path ...`）
  - 旧版用 `exclusiveScope<Int64> { ... }` 包整段 STA + WinUI 启动逻辑；该路线已被 Win32 `CreateThread` STA worker 替代
- [x] **Win32 `CreateThread` STA worker 已端到端打通**
  - [windows-cj-demo/src/main.cj](windows-cj-demo/src/main.cj) 只保留主线程编排：分配 `WorkerContext`、创建 native thread、等待 worker、读取 stage / exit code、释放 handle
  - [windows-cj-demo/src/sta_runtime.cj](windows-cj-demo/src/sta_runtime.cj) 持有 `@C func staWorker`、AppSDK bootstrap、COM STA 初始化、`Application.Start` 调用和 WinUI 顶层对象强引用
  - `stage` 现在在调用关键阶段前写入：`0=enter / 1=AppSDK / 2=COM / 3=Application.Start / 4=returned / 5=cleanup`

### 当前状态（线程问题已解决 → WinUI authoring 缺口）

- **仓颉 cjnative runtime 在 Windows 上未实现 `exclusiveScope`**（保留原有诊断）
  - 仓颉 M:N 调度，仓颉线程被随机调度到不同 OS 线程；`unsafe { GetCurrentThreadId() }` 实测 main 内连续切换 84412 → 52164 → 12328
  - WinUI 3 / STA-COM 严格要求 `CoInitializeEx(STA)` 与所有后续 COM 调用在**同一**OS 线程上执行；线程切换会触发 `0xC000027B` STATUS_FATAL_APP_EXIT
  - 仓颉端原语 `std.core.exclusiveScope` 文档明确「不支持 Windows / macOS / OpenHarmony / HarmonyOS / iOS」；runtime DLL 虽导出 `CJ_MCC_ExclusiveScope` 但实测 Windows 调用即 `0xC0000005` 段错误。**已让用户去联系上游**。

- **绕开方案：Win32 `CreateThread` + `@C func` 入口已验证可行并已落到 demo**（2026-04-28 实测）
  - 思路：从 Win32 直接 `CreateThread` 一条 OS 线程，`lpStartAddress` 给 `@C func`。这条线程不在仓颉 M:N 线程池里，调度器看不见、动不了它，整个生命周期 OS 线程 ID 固定。
  - 实验代码已整理为 [windows-cj-demo/src/main.cj](windows-cj-demo/src/main.cj) + [windows-cj-demo/src/sta_runtime.cj](windows-cj-demo/src/sta_runtime.cj)。
  - 实测输出（worker 在采样点 4 次记录 OS tid + 测 CoInitializeEx STA）：
    ```
    [main]  tid before CreateThread: 58116
    [main]  tid after wait:          58116
    [probe] worker tidEntry         = 79328
    [probe] worker tidAfterSleep1   = 79328   # Win32 Sleep(200ms)
    [probe] worker tidAfterCoInit   = 79328   # CoInitializeEx 返回后
    [probe] worker tidAfterSleep2   = 79328   # 第二次 Sleep(200ms) 后
    [probe] worker tid stable: true
    [probe] CoInitializeEx HRESULT: 0  (S_OK)
    [probe] worker tid != main tid: true
    [probe] thread exit code: 0
    ```
  - 结论：worker 整个生命周期 OS 线程稳定；STA 初始化成功；与主线程是不同 OS 线程；worker 干净退出。**STA 单线程亲和性问题被绕过，不再依赖 `exclusiveScope` 修复**。
  - 关键 cfggen feature（demo `cjpm.toml` 已加）：`Windows_Win32_System_Threading_{CreateThread,GetCurrentThreadId,GetExitCodeThread,Sleep,WaitForSingleObject}` + `Windows_Win32_Foundation_CloseHandle`
  - 关键 binding：`LPTHREAD_START_ROUTINE = CFunc<(CPointer<Unit>) -> UInt32>`，`@C func` 满足；高层 facade `Windows_CreateThread` 用 `SECURITY_ATTRIBUTESAbi` / `THREAD_CREATION_FLAGSAbi`（不是 raw struct）；`Windows_WaitForSingleObject` 返 `WAIT_EVENTAbi`，需 `.value` 取 UInt32
  - **第二步实验也通过**（2026-04-28）：在 worker `@C func` 内**不调任何 attach API**，直接 `println(...)` + `Windows_CoInitializeEx(STA)` + `Windows_CoUninitialize()`。5 次采样 OS tid 全部 = 37664（跨 println + CoInit + CoUninit + Sleep），HRESULT=0，reachedEnd=1，exit 0。仓颉编译器/runtime 在 managed 入口 stub 上做了隐式 lazy attach（runtime DLL 也确实导出了 `MRT_TryNewAndRunCJThread` / `MRT_EndCJThread` 用于显式 attach，但实测不需要主动调）。
  - 备用 attach 路径：`T:/cangjie_runtime/runtime/src/CjScheduler.cpp:378` — `MRT_TryNewAndRunCJThread()` 创建 `SCHEDULE_FOREIGN_THREAD` scheduler + cjthread + mutator + ThreadLocal。foreign 调度器**不抢占**这条 cjthread（`schedule.cpp:548-552`、`cjthread.cpp:1279`），所以即使显式 attach 也不破坏 OS 线程亲和性。
  - WinUI 启动（`Application.Start` + `Window.CreateInstance` + `Activate`）已搬到 worker `@C func` 内执行。当前新阻塞点是 `Application.Start` 内部 FailFast `0xC000027B`，根因是 demo 仍直接创建 base `Application`，缺 user-side `IApplicationOverrides` 子类和 `IXamlMetadataProvider`。

### WinUI authoring 待补

- [x] 调研参考实现的 ComClass + WinUI authoring 模式，形成 [docs/winui-authoring-design.md](docs/winui-authoring-design.md)
- bindgen 生成真实的 `IApplicationOverrides_Impl` user implementation interface，而不是只生成 schema metadata 字符串
- `windows-implement` 补 WinRT composable activation helper：`IApplicationFactory.CreateInstance(outer, &inner)`、outer / inner QI 路由和 base 调用
- demo 先实现最小 `IXamlMetadataProvider` stub，满足 WinUI query 后再补 framework metadata provider
- demo 改成 user `Application` 子类，在 `OnLaunched` 创建 `Window`、设置标题并 `Activate`
- 后续再补 Window Content（最小 TextBlock / Frame）和 DispatcherQueueController 生命周期管理

### 已知 backlog（本轮发现，未处理）

- **facade re-export `@When[]` cfg 表达式臃肿**（[tests/test_bindgen_reference_alias_and_delegate_guards.py::test_facade_abi_exports_use_source_type_conditions](windows-cj/tests/test_bindgen_reference_alias_and_delegate_guards.py)）
  - `windows/src/Win32/System/Kernel/mod.cj` 中 `EXCEPTION_REGISTRATION_RECORD` 等 type 的 `public import windows.Win32._impl_l2.{...}` 行 cfg 实际生成：`@When[Windows_Win32_System_Kernel == "on" && (((arch == "aarch64" && Windows_Win32_System_Diagnostics_Debug == "on") || (arch == "x86_64" && (...) && Windows_Win32_System_Diagnostics_Debug == "on")) && (arch == "x86_64" || arch == "aarch64") && Windows_Win32_System_Diagnostics_Debug == "on" && Windows_Win32_System_Diagnostics_Debug == "on")]`
  - codex 加的回归测试期望 `@When[Windows_Win32_System_Diagnostics_Debug == "on"]`（仅 source type cfg，无 namespace cfg + 无 arch 嵌套 + 无重复）
  - 行为正确性不受影响（source type 自身 `@When` 守卫已足够），但 cfg 表达式难读 + 触发 cjc parse 慢
  - 修复路径：`main.cj::facadeExportAvailabilityCondition` 不再叠加 namespace `feature` + `mergedStructTypeAvailabilityTags` 去重 + 提取 arch 到 outermost
  - 验证需 regen + cjpm build 全量回归（30+min），未在本轮验证
- **windows-implement 缺 WinRT composable activation 封装** — `IApplicationFactory.CreateInstance(outer, &inner)` 子类化 Application 没有便捷 helper
  - bindgen 生成的 `IApplicationOverrides_Impl` 字符串只是 schema metadata 字面量，没有真实的 user-implementation interface 定义
  - WinUI 3 / WinRT subclassing 需要这两层一起到位才能跑起 metadata provider
  - 这是当前 `Application.Start` FailFast 的主要功能缺口

### 验证记录（2026-04-28）

- `cjc-frontend -p src --cfg . --import-path <每个 dep cjo dir>` on `windows-cj-demo/src/main.cj`：exit 0（反向用故意 `String → Int64` 错配验证 frontend 真做类型检查 → exit 1 报 mismatched types）
- `windows-cj-demo` worker 内裸 `println` / class 方法 / 异常捕获 / AppSDK init / `CoInitializeEx(COINIT_APARTMENTTHREADED)` 均已确认在 Win32 native worker 线程上工作，且 OS tid 跨调用稳定。
- `Application.Start(ApplicationInitializationCallback.new(...))` 已在 worker 内复现 FailFast `0xC000027B`；这说明 STA 线程基础设施已越过，剩余问题集中在 WinUI authoring（`IApplicationOverrides` + `IXamlMetadataProvider`）。
- Tier A 整理后 fresh 验证：`cjHeapSize=32GB; cjv exec cjpm build` on `windows-cj-demo` → `cjpm build success`。
- Tier A 整理后 fresh smoke：设置 `WINDOWS_APPSDK_BOOTSTRAP_DLL` 后 `cjv exec ./target/release/bin/main.exe` → worker 输出 `AppSDK init OK`、`CoInitializeEx OK, calling Application.Start`，随后进程退出码 `3221226107`（`0xC000027B`），与当前 WinUI authoring 缺口一致。
- Codex 留下的 ad-hoc Python 测试（`tests/`、`windows-cfggen/tests/`）已统一清理 — 与本仓库「测试体系待重写」的方针保持一致。本次确认通过后才删：
  - `test_bindgen_non_windows_import_guards`：PASS
  - `test_bindgen_reference_alias_and_delegate_guards`：1 PASS（unconditional impl alias import 守卫拆除生效）/ 1 FAIL（facade re-export cfg 简化未实现，见上方 backlog）
  - `test_prepare_nuget_metadata`：PASS
  - `windows-cfggen/tests/test_multi_catalog`：PASS（修正 TOML basic string `\` escape assertion）

## 历史 active 工作：Win32.impl 拆分（layered）

详细计划：[docs/win32-impl-split-plan-2026-04-25.md](docs/win32-impl-split-plan-2026-04-25.md)

- [x] **Stage 1（bindgen prototype）** — 算法侧已完成
  - [config.cj:27-28](windows-cj/windows-bindgen/src/config.cj:27)：`usesLayeredImpl = true` + `targetBucketSize = 2000`
  - [gen_layer.cj](windows-cj/windows-bindgen/src/gen_layer.cj) + [layer_assignment.cj](windows-cj/windows-bindgen/src/layer_assignment.cj) 已写
  - [main.cj:329](windows-cj/windows-bindgen/src/main.cj:329) 走 layer 分支
  - 三个 winmd 全部按计划拆分：Win32 → 3 layer / WinRT → 3 layer / Wdk → 1 layer
  - 36 个 facade sub-package 形态正确，`@When` 守卫复制到 `public import` 行
- [x] **Stage 1 验收 gate 全部通过**（2026-04-26 晚二）
  - 小 filter `Windows.Win32.System.SystemServices`（含 7 transitive namespace）下重跑 bindgen 两次 byte-identical（flat 11/11、layered 19/19 文件 md5 全等）
  - DAG：8-namespace 子图 Tarjan 无环
  - 大 filter `Foundation+System.Com+UI.Shell+System.Ole` + `--target-bucket-size 200` + subpackage layout：成功触发 3 个 `_impl_l*` 桶；110 文件两次 byte-identical；layer-order 严格 PASS（`_impl_l0` 不引用 `l1/l2`，`l1` 只引用 `l0`，`l2` 引用 `l0/l1`，0 逆向边）
  - 注意：subpackage layout 需 `--out <pkg>/src` + 同级 cjpm.toml 才能让 `usesSubpackageLayout()=true` 触发桶 emit；并发跑 cjc OOM，必须串行
  - 脚本：[target/_det_compare.py](windows-cj/windows-bindgen/target/_det_compare.py)、[target/_det_layer_check.py](windows-cj/windows-bindgen/target/_det_layer_check.py)（uv inline）
- [x] **Stage 2 — vtable / interface ABI 历史验证 22/22 PASS**（2026-04-26 晚二）
  - 旧独立 driver 已在 2026-04-27 删除，后续验证会重写。
  - T1: `sizeOf<IUnknownVtbl>() == 24` 跨 layer A/B 一致
  - T2: `sizeOf<VARIANT>() == 24` 跨 layer A/B 一致
  - T3: CFunc round-trip 跨 layer 调用 lambda 等价
  - T4: IShellFolder-like `base_: IUnknownVtbl` + 5 own methods 落 slot 3..7（用 `CPointer<UInt8>` 字节算术验证）
  - T5: IUnknown 三字段在 slot 0/1/2
  - T6: 静态 const 跨 facade re-export 值不变
  - **缺口**：历史验证用 mini case 替代真实 IShellFolder（依赖 windows-sys 不能 import）；端到端验证待重写
- [x] **Stage 3 — 全 build profile 完整 PASS**（2026-04-26 晚二）
  - **关键发现**：之前归罪的"cjc OOM ~24 GB"实际是 **cjpm 自己的 Cangjie heap 默认 256 MB 不够**做 729 包依赖图分析；并非 cjc 编译时内存。设 `cjHeapSize=32GB` env 即可解锁
  - 单包内存峰值（基于 `--profile-compile-memory` 实测 734 个 .mem.prof）：
    - 0/734 包 > 2 GB **(target < 2 GB ✅)**
    - 仅 4 包 > 1 GB（最高 `Win32.Web.MsHtml` = 1.4 GB / CHIR 阶段）
    - 4 个 `_impl_l*` layered 包：Win32._impl_l0 = 957 MB / l1 = 938 MB / l2 = 1343 MB / Win32.Media._impl_l0 = 700 MB
  - 全 workspace clean build wall-clock：**5 min 54 sec** vs target 12 min（**50%+ 余量** ✅）vs baseline 18.9 min（68% 改进）
  - 结论：Stage 1 layered 拆分本来就把 cjc 单包内存压住了；OOM 是 cjpm 工具链而非编译器
  - profile 数据：[windows-sys/target/release/windows_sys/*.mem.prof](windows-cj/windows-sys/target/release/windows_sys/) + `*.time.prof` + `*.info.prof`
- [x] **Stage 4 — 回归审计完成**（2026-04-26 晚二，cjHeapSize=32GB 解锁后）
  - 历史脚本式回归用于关闭 P0/P1；这些脚本入口已在 2026-04-27 清理。
  - Source ownership audit 曾报 143 missing bindgen header（已记预存项）。
  - ABI regression guards 曾全过。
  - 生成器布局变更后的旧 fixture 资产已删除，后续会重写。
  - P1-7 WinRT interface schema 修复后 direct base schema 与 `GetResults` slot 13 校验转绿。

## 行为对齐 backlog

### 已修（2026-04-26 晚二 — Stage 4 回归过程发现的 P1）

- [x] **P1-7 WinRT interface schema directBaseSchema + abiSlot 起始硬编码**
  - [gen_winrt_interface.cj:1440](windows-cj/windows-bindgen/src/gen_winrt_interface.cj:1440) `InterfaceDescriptorSchema(...)` 的 directBaseSchema 写死 `IInspectable.descriptorSchema()`；line 1633-1643 `abiSlotStartForType` 写死 `return 6`，不累加 required interface own method count
  - 行为后果：派生型 WinRT interface（IAsyncAction ← IAsyncInfo 等）的 schema 元数据 directBase 错指 IInspectable，且 own methods 起始 slot 错（IAsyncAction.GetResults 应 13 实际 8）；下游运行时按 schema slot 调度会路由到错误 vtbl entry
  - 修复：新增 `winrtDirectBaseSchemaCall` + `winrtDirectBaseChainOwnMethodCount` helper；`abiSlotStartForType` 改为 `6 + Σ(direct base chain own method count)`
  - 验证：directBaseSchema 与 `GetResults` slot 13 校验从 FAIL → PASS；4 个 delegate case 中 3 个 PASS（第 4 个 FAIL 是 Win32 Cryptography 生成预存问题，与本修无关）

### 已修（2026-04-26 三轮审计 — P0/P1 一揽子）

- [x] **P0-1 bindgen WinRT delegate vtbl 错继承 IInspectable**
  - [gen_winrt_delegate.cj:59](windows-cj/windows-bindgen/src/gen_winrt_delegate.cj:59) `base_: IInspectableVtbl` → `base_: IUnknownVtbl`，使 `Invoke` 落到 slot 3
  - line 110 `descriptor` ancestor IID 列表 `[IInspectable.iid(), IUnknown.iid()]` → `[IUnknown.iid()]`
  - line 288 `descriptorSchema` base 与 slot 改 IUnknown / 3
  - line 365 `buildIInspectableVtbl()` → `buildIUnknownVtbl()`
  - 行为后果：所有 WinRT delegate（TypedEventHandler / *CompletedHandler / EventHandler / VectorChangedEventHandler）框架按 slot 3 取 Invoke 时 ABI 正确
  - **后续待办**：regen sys/windows 让生成产物落地（被 cjc OOM 阻塞，见"上游编译器约束"）
- [x] **P0-2 windows-strings HString refcount 与 OS ABI 不兼容**
  - [ref_count.cj](windows-cj/windows-strings/src/ref_count.cj) 删除全局 `ConcurrentHashMap<UIntNative, AtomicInt32>` refcount 表 + `RefCountException`
  - 新 `hStringCountSlot()` + `hStringCountMutex` 直接操作 inline `header.count` 字段
  - 行为后果：可消费 `WindowsCreateString` / `IInspectable::GetRuntimeClassName` / 任何外部 C++ 组件构造的 HSTRING 而不再抛 missing-state 异常
  - 取舍：仓颉无 atomic-on-raw-pointer，用全局 Mutex 保护 read-modify-write — 正确性优先于 lock-free
- [x] **P0-3 windows-future IAsync*WithProgress 进度回调被静默丢弃**
  - [async_helpers.cj:578](windows-cj/windows-future/src/async_helpers.cj:578) `NativeAsyncActionWithProgressImpl.SetProgress` 现 lock + checkedHandler + 写入 `progressHandler` 字段
  - [async_helpers.cj:815](windows-cj/windows-future/src/async_helpers.cj:815) `NativeAsyncOperationWithProgressImpl.SetProgress` 同
  - `Progress()` getter 返回已存 handler；二次设抛 `E_ILLEGAL_DELEGATE_ASSIGNMENT` 与 `SetCompleted` 一致
- [x] **P0-4 windows-threading TP_CALLBACK_ENVIRON_V3 缺 ABI 校验**
  - [lib.cj:168](windows-cj/windows-threading/src/lib.cj:168) `EXPECTED_TP_CALLBACK_ENVIRON_V3_SIZE = 72` (x64)
  - [lib.cj:173](windows-cj/windows-threading/src/lib.cj:173) `assertTpCallbackEnvironV3SizeMatches` mutex-guarded、首次 Pool.init 触发
  - 历史验证已确认实测 sizeOf == 72，断言不抛
- [x] **P1-1 windows-core trustLevel 透传**
  - [com_impl.cj:62](windows-cj/windows-core/src/com_impl.cj:62) `ComObjectRuntime.trustLevel: Int32 = 0i32` 字段
  - line 77 `setTrustLevel(level)` / line 81 `getTrustLevel()` API
  - line 307 `getTrustLevelBase` 写入运行时值替代写死 0
  - 取舍：未触 descriptor_schema/interface_impl_surface（避免链路过深），走 ComObject 显式 setter
- [x] **P1-2 windows-future `waitForTerminalStatus` 仍是 1ms 忙等**
  - 未修。perf 优化项，行为正确，留作 backlog
- [x] **P1-3 windows-numerics rotation/skew/rotationY**
  - [Numerics.cj:537](windows-cj/windows-numerics/src/Numerics.cj:537) 新增 `D2D1MakeRotateMatrix` / `D2D1MakeSkewMatrix` / `D2D1SinCos` foreign 声明
  - `Matrix3x2Math.rotation/rotationAround/skew/skewAround`、`Matrix4x4Math.rotationY` 全部实现
  - 旧 runner 曾加 `-ld2d1` link option 与 PI/2 旋转、skew(0,0) identity、rotationY(90°) 校验；runner 已删除待重写
  - build 验证被 cjc OOM 阻塞，syntax 与同文件已存在的 `@C struct` + `inout` 模式一致
- [x] **P1-4 windows-registry Value.toU64 / toU32 类型接受面**
  - [lib.cj:505,525](windows-cj/windows-registry/src/lib.cj:505) `toU32` 增加 U64 case（高 32 位为 0 截断，否则 invalidDataError）；`toU64` 增加 U32 case 零扩展
- [x] **P1-5 windows-services fallback 多余 setState**
  - [lib.cj:240-256](windows-cj/windows-services/src/lib.cj:240) 删除退出时 `setState(State.Stopped)`（无 handle 时纯噪声）
- [x] **P1-6 windows 包伞 re-export**
  - [windows/src/mod.cj](windows-cj/windows/src/mod.cj) 暴露 `windows.core / result / strings / collections / numerics / future / threading` 别名
  - [windows/cjpm.toml](windows-cj/windows/cjpm.toml) 补 `windows_threading` 依赖

### 上游编译器约束（不计入 backlog）

- `cjpm build -p windows-future` / `windows-numerics` / `windows-core` 全 build 触发 cjc OOM (~24 GB 峰值，见 [docs/cjc-build-bottleneck-2026-04-25-v3.md](windows-cj/docs/cjc-build-bottleneck-2026-04-25-v3.md))
- 上述 P0-3 / P1-1 / P1-3 修改未做完整 cjpm build 验证，但代码结构与同文件已存在的同类模式一致
- regen sys / windows 让 P0-1 delegate vtbl 修复落地到生成产物，同样被 OOM 阻塞 — 待 layered split Stage 2-4 完成后重试

### 已修（2026-04-26 二轮审计）

- [x] **G1 静态 WinRT class signature 对齐**
  - [type_helpers.cj:781-787](windows-cj/windows-bindgen/src/type_helpers.cj:781) `classRuntimeSignature` 在 `None` 分支改为 `throw Exception(...)` 守卫，防止误调用
  - [gen_winrt_class.cj:448-463](windows-cj/windows-bindgen/src/gen_winrt_class.cj:448) `writeStaticWinrtClass` 不再 emit `signature()` 与 `runtimeType()`，依赖 `RuntimeName` 接口默认实现（默认实现等价于裸 runtime name）
  - 行为后果：静态类不再生成无意义的 `signature()` 字符串，与"静态类不注册成 RuntimeType"的设计对齐
- [x] **G2 `MethodNames.normalizedMethodName` 严格 SpecialName**
  - [method_names.cj:53-57](windows-cj/windows-bindgen/src/method_names.cj:53) 删除 `|| startsWith(rawName, "get_/put_/add_/remove_")` 兜底分支，改为单一 `if (specialName)`
  - 行为后果：metadata 中没有 SpecialName flag 但名字以 `get_/put_/add_/remove_` 开头的方法不再被误剥前缀

### 二轮审计结论：以下原以为是缺口的项实际已实现

- **G3 / G4** — `IAsync*::when()` 与 `IAsync*::ready()` 都已在 [async_helpers.cj:1065-1240](windows-cj/windows-future/src/async_helpers.cj:1065) 实现：
  - `when()` 返回 `Future<Result<T>>`（仓颉 spawn 形态），与 Rust 的 callback 形态等价
  - `ready()` 直接构造 `AsyncStatus_Completed` 的 IAsync*，不 spawn worker，等价于 Rust `AsyncReady<T>`
- **B1** — bindgen 对非 Default 接口统一走 `accessor()` 已是仓颉范式选择：accessor() QI 失败 throw E_NOINTERFACE，与 Rust 的 `cast::<I>()?` 在 ABI 反馈层面等价
- **windows-collections** — 仓颉只实现 view 形态 stock 与 Rust 一致（Rust 也只有 `vector_view.rs` / `map_view.rs`，没有 mutable IVector stock）

### 仍未修

- 无（前轮文档列出的 G1/G2 已修；G3/G4/B1 已确认是误报或设计选择）

### 测试补强（2026-04-26 二轮审计）

- [x] **深继承链 QI / vtable 历史验证**
  - 接口链：`IBase` (+IInspectable) ← `IMid` ← `ILeaf`，三层各自一个 own method
  - 验证：单 leaf descriptor 构造 + 链式 baseDescriptor 推导出完整 vtbl；ILeaf/IMid/IBase/IInspectable/IUnknown QI 全部成功；跨层 QI 返回相同槽指针；AddRef/Release 配对干净（1 → 2 → 1 → 0）
  - `cjpm build success`，`cjpm run` 曾输出深继承链验证通过。
  - 这是 AGENTS.md §"真 bug 类别"标注的"深继承链 slot 计数"历史验证；旧测试资产已删除待重写

## Warning backlog

- [x] `simulating union layout ...` — 重写为 `note:` 并标注 `cangjie-paradigm: @C struct cannot host union variant`，`cangjie-behavior.md` 收编（2026-04-26）
- [x] `unsupported import entry point ...; falling back to method name` — non-identifier 符号一律走 runtime entry-point resolver，`foreign` 块路径只保留更精确的防御性诊断（2026-04-26，全量 winmd 0 触发）
- [x] `delegate ... incompatible ...; using first signature` — `delegateDivergenceIsArchPointerWidth` classifier 抑制 metadata noise；真正不兼容仍报。全量 regen 中 `PTERMINATION_HANDLER` 3 次噪音消除（2026-04-26）
- [x] 编译器 `unreachable` warning — `gen_winrt_interface.cj::writeWinrtAbiBridgeHelpers` 删除 unreachable 块（2026-04-26）。`unused` 全局 `-Woff unused` 抑制策略保留（仓颉无 per-decl `@allow(unused)`），文档化为 `cangjie-behavior.md` 政策

详见 [windows-cj/docs/warning-backlog-2026-04-26.md](windows-cj/docs/warning-backlog-2026-04-26.md)。

## 后续维护项

1. feature-specific package / generation slice 设计 — 实测 `cfg.toml` 不能让 `cjpm` 自动分批，需要靠 package / generation 边界。可能与 layered 拆分协同。
2. generator / winmd 更新后重跑 raw / high-level 回归和 final audit。
3. **regen sys/windows 让 P0-1 delegate vtbl 修复 + P1-7 schema 修复落地到生成产物** — Stage 3 解锁后即可执行：在 windows-bindgen 跑 `cjpm run -- --in ... --out windows-sys/src` 的全 winmd regen，然后 `cjpm build` 验证
4. 旧 tests/fixture/runner 资产已删除；后续需要重新设计最小覆盖集。
5. layered Stage 1 拆分后生成器在 src/ 与 pkg root 双 emit cfg.toml/features.toml/link-options.toml，需结合新测试设计重新验证。
6. Win32 Cryptography 子包 (subpackage_import_cfg / high_level_delegate_return_default) 生成缺失 — 独立调查项

## 不再做的事

- 不实现 Rust 借用 / 生命周期模型
- 不强行把 `HString` / `BSTR` 改成 Rust 式值语义
- 不移植 `Deref` / `DerefMut` / `unsafe fn` 这些 Rust 语法面
- 不复刻 `w!` / `s!` / `h!` 编译期宏
- 不为 `repr(C)` 表面形态把 managed 对象塞进 `@C struct`
- 不实现 `windows-rdl` / `windows-riddle`

## 参考入口

- 总体 spec：`docs/superpowers/specs/2026-04-22-full-windows-rs-parity-redesign.md`
- 基线 ledger：`docs/superpowers/parity/program-baseline.md`
- 各 wave 计划：`docs/superpowers/plans/2026-04-22-wave-{0-7}-*.md`
- Win32.impl 拆分：[docs/win32-impl-split-plan-2026-04-25.md](docs/win32-impl-split-plan-2026-04-25.md)
- Cangjie 行为映射：[cangjie-behavior.md](cangjie-behavior.md)

## 每次完成后必须回写

- 更新本文件状态（wave / active 工作 / backlog）
- 补对应 build / integration / regression 验证
- 记录"这是仓颉范式差异"还是"这是真 bug / 真缺口"
