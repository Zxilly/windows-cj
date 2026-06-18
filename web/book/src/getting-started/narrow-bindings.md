# 按 app 裁剪绑定收缩二进制

`windows_bindgen` 默认按命名空间（feature）生成绑定。但即使只开应用真正用到的那些命名空间，一个命名空间里仍会带进成千上万个应用从不触碰的类型。本章介绍**按 app 裁剪**：为单个应用生成一个**窄** `windows_sys`，只含它实际用到的 Windows 类型（外加自动传递闭包），从而把二进制收缩到接近参考投影的量级。

## 为什么必须在生成期裁剪

完整 `windows_sys`（729 包、59,462 个符号）会把每个启用命名空间里的每个类型都编进二进制。仓颉类型携带运行期元数据，且被 `llvm.used` 钉死——链接器**删不掉**它们，`--gc-sections` / `--strip-all` 也无能为力。**编进去 = 占体积**。要收缩二进制，唯一办法是**一开始就不生成无用类型**。这正是参考投影能产出极小二进制的原因：它的 bindgen 只渲染消费者引用到的类型。按 app 裁剪复刻了同一思路。

## 一条命令跑完

```powershell
python scripts/gen_app_narrow_bindings.py                  # 默认 = 2048 demo
python scripts/gen_app_narrow_bindings.py --app <dir>      # 任意 reactor app
python scripts/gen_app_narrow_bindings.py --app <dir> --skip-build  # 只暂存不构建
python scripts/gen_app_narrow_bindings.py --reuse-sys      # 复用已生成的窄 sys
python scripts/gen_app_narrow_bindings.py --reuse-ws       # 复用已暂存的 workspace
```

`scripts/gen_app_narrow_bindings.py` 端到端跑完整流程：

1. **提取** — 扫 `windows_reactor/src` 与 app 自己的 `src` 里的 `windows_sys` import，推导出精确的**按类型** filter 种子集（写入 `scripts/narrow_app_seeds.json`）。
2. **生成** — 对每个种子跑 `windows_bindgen --filter <seed>`，产出只含种子 + 其**自动传递闭包**（基类、字段、方法/属性签名、特性）的窄 `windows_sys`。
3. **暂存** — 搭一个临时 cjpm workspace，其唯一的 `windows_sys` 成员**就是**这个窄版，外加一份指向它的 app 副本，cfg 恰好门控到窄闭包定义的那些命名空间。
4. **构建** — 用 gating 工具链对暂存 app clean-build，报出 exe 体积 + 挂钟时间。

签入仓库的真 `windows_sys` 与 `windows_reactor` **全程只读、不被修改**；所有产物落在 sibling 的 `_narrow_*` / `*-narrow` 目录。

## 体积 / 时间收益（2048 demo 实测）

| 绑定集 | 符号数 | exe 体积 | 构建时间 | vs 全量 |
|---|---|---|---|---|
| 全量 `windows_sys`（`--feature all`） | 59,462 | 393.8 MB | ~26 min | 1.00× |
| 窄，**按命名空间** filter | 20,669 | 264.9 MB | ~9.4 min | 0.67× |
| 窄，**按类型** filter | **2,949** | **111.4 MB** | **~5.2 min** | **0.28×** |

按类型裁剪是该落地的方案：只编全量约 5% 的符号，产出比全量**小 71.7%** / 比按命名空间**小 42%** 的二进制，构建快约 5×。按命名空间裁剪卡在 0.67× 的天花板——启用整个命名空间（如 `Microsoft.UI.Xaml.Controls`）会拖进数千个 app 从不触碰的类型；按类型裁剪突破了它。

## 种子提取器如何做到零闭包缺口

`--filter` 按完整类型名、去元数短名、或命名空间前缀匹配记录；依赖闭包自动计算。有三种 import 形态**不可**直接 filter，提取器为每种自动推导出一个可 filter 的种子（零手补，已验证零闭包缺口）：

| app 源码里的 import 形态 | 为何不可 filter | 自动推导的种子 |
|---|---|---|
| `import windows_sys.X.{IFooVtbl}`（`*Vtbl` 伴生结构） | Vtbl 结构随其接口一并生成，不是独立记录 | 父接口 `X.IFoo`（去掉 `Vtbl`） |
| `import windows_sys.A.B.C as Y`，其中 `A.B.C` 是**命名空间**（整命名空间导入，如取 `CoInitializeEx` 这类 P/Invoke 函数） | 路径指向命名空间而非类型记录 | 命名空间种子 `A.B.C` |
| `import windows_sys.Foundation.{IReference}`（泛型类型） | 元数据完整名带反引号元数（`` IReference`1 ``），裸完整名匹配不到 | 去元数短名 `IReference`（bindgen 按 `record.name` 匹配泛型） |

消歧用签入的完整 `windows_sys/codegen-manifest.json` 作**只读 oracle**（每个类型完整名 + 每个命名空间前缀），据此判断 `import ... .Com as X` 指类型还是命名空间、某名是否是需要短名种子的泛型。枚举成员伪常量（`import ... .{Stretch_None}`）同样不可 filter，提取器改种父枚举（`Stretch`）。

## 两个铺开摩擦（工具已内置规避）

1. **cjpm workspace 成员注入。** `windows-cj/cjpm.toml` 是个 cjpm `[workspace]`，`windows_sys` 是其成员。任何指向 workspace 的依赖路径都会让 cjpm 注入**全部**成员，于是窄 `windows_sys` 与真成员撞名（`modules with name 'windows_sys' are conflicted`）。工具用**暂存临时 workspace**绕开：它是 `windows-cj` 的副本（排除 `target/`，并把真 `windows_sys` 的 *src* 换成窄内容、保持同包名），整棵树只有一个 `windows_sys`。真 workspace 下的一切都不被触碰。（永久替代方案：把 `windows_sys` 从 workspace `members` 列表移除。）

2. **GC mutator-lock 看门狗 ICE。** 全并行构建下运行期的 mutator-lock 看门狗可能编译途中触发（`Wait mutator list lock timeout`，在重命名空间包上崩），即便设了 `cjMutatorLockTimeout=240` 也可能。工具用 **`-j 4`** 构建以削减并发 cjc 的 mutator 争用，能干净通过。（exe 体积与并行度无关，只影响构建时间，所以 ~5.2 min 偏保守——看门狗允许时更高 `-j` 会更快。）

所有构建都带 `cjHeapSize=32GB`、`cjMutatorLockTimeout=240`、gating 工具链（`dev_perf_ci`，含快速 cfg 求值路径）。
