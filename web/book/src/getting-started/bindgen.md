# 用 windows_bindgen 生成绑定

到目前为止，你用到的都是仓库里已经签入的支持包（`windows_core`、`windows_strings`、`windows_common` 等）。但 Windows 的 API 表面极其庞大，仓库不可能把每一个命名空间都预先投影进来。当你需要某个还没被签入的命名空间时，就轮到 `windows_bindgen` 登场了——它按需把 Windows 元数据生成成仓颉源码包。

## windows_bindgen 是什么

`windows_bindgen` 是一个**独立于运行时**的命令行工具。它的职责只有一个：读取 Windows 元数据（`.winmd`），按你选定的 feature 把对应的类型、函数、接口渲染成仓颉源码，写到一个目录里。

记住这一点：**它本身不是可直接消费的 Windows API 投影**。它是生成器，不是被生成物。你不会 `import windows_bindgen` 去调用 Windows API；你运行它，得到一个新的源码包，然后在自己的项目里以路径依赖去消费那个包。

它的仓颉包名是 `windows_bindgen`，面向用户的命令名是 `windows_bindgen`。元数据读取走的是内置的仓颉原生 `.winmd` 解析器——你不需要任何外部转换器；只要把 `.winmd` 文件、`.winmd` 目录，或关键字 `default`（解析仓库自带的元数据）交给它即可。

## 构建这个 CLI

`windows_bindgen` 是工作区里 `output-type = "executable"` 的一个成员。先把它构建出来：

```powershell
$env:cjHeapSize = '32GB'
cjpm build
```

构建产物是一个可执行文件，位于：

```text
target\release\bin\windows_bindgen.exe
```

和本书一贯的约定一样，**不要直接双击或裸跑这个 `.exe`**。通过仓颉版本管理器的 `cjv exec` 包裹运行，才能保证运行时链接到与编译期一致的仓颉运行时：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe --help
```

> 下文所有命令示例都假设你已经构建好 CLI。为简洁起见，示例统一写成 `cjv exec .\target\release\bin\windows_bindgen.exe ...`，请在仓库根目录执行。

## CLI 参数逐个看

下面这些参数都来自生成器的真实参数解析逻辑，含义以源码为准。

### `--list-features`：先看看有哪些 feature

不带选择规则时，先列出当前元数据里可用的 feature（即命名空间）。这通常是你的第一步：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default --list-features
```

`default` 表示解析仓库自带的元数据。输出里每一行就是一个可作为 `--feature` 值的命名空间，外加一个特殊的 `all`（表示全选）。

### `--feature`：选择要生成的命名空间

`--feature <namespace>` 指定一个要生成的命名空间。它可以重复出现，多次叠加：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --feature Windows.Win32.System.Com
```

生成器会把你选中的符号，连同它们依赖的其它符号一起拉进来（依赖闭包自动计算），所以你通常只需要点名顶层命名空间即可。

### `--out`：生成到哪个目录

`--out <dir>` 指定输出目录。默认是 `.generated/windows`：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --out .generated\my-windows
```

### `--clean`：生成前清空输出目录

`--clean` 在写入前先删除输出目录，避免上一次生成残留的过期文件混进来：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --out .generated\my-windows `
  --clean
```

### `--dry-run`：只算不写

`--dry-run` 走完整的选择与渲染流程，但**不真正写文件**。用它来预演一次生成会产出哪些内容、有没有报未知 feature 的错，而不污染磁盘：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --dry-run
```

### `--manifest`：把清单写到指定路径

每次生成都会产出一份 `codegen-manifest.json`，记录请求的 feature、选中的符号列表、生成的文件清单以及各文件的哈希。默认情况下它被写进输出目录；`--manifest <path>` 让你把这份清单单独写到指定路径：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --out .generated\my-windows `
  --manifest .generated\my-windows.manifest.json
```

### `--common`：面向中心仓维护者

`--common` 是一个特殊模式，面向**仓库维护者**而非普通消费者。它按稳定支持包（`windows_version` / `windows_registry` / `windows_threading` / `windows_foundation` / `windows_collections` / `windows_winui3` 等）所需的命名空间，生成或更新与它们并列的 `windows_common` 包。开启它会把包名固定为 `windows_common`，并把默认输出目录改为 `windows_common`。

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default --common
```

作为普通使用者，你一般不需要它——它存在的意义是让维护者刷新签入仓库的中心支持包。概念上理解即可。

> 除了上面这些，生成器还接受一些进阶参数：`--filter <rule>`（更细粒度的符号选择，支持通配符与 `!` 排除）、`--package-name <name>`（覆盖生成包名）、`--input-json` / `--input-dir`（喂入已转换好的离线 JSON 元数据，而不是直接解析 `.winmd`）、`--print-link-options`、`--sys`、`--implement`、`--no-comment`、`--derive` 等。运行 `--help` 可以看到完整说明。本页只展开最常用的那几个。

## 端到端：从列举到消费

把上面的步骤串起来，就是一条完整的工作流。

**第一步：列出可用 feature。**

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default --list-features
```

**第二步：选一个 feature，干净地生成到 `--out` 目录。**

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --out .generated\windows `
  --clean
```

**第三步：在你自己的项目里以路径依赖消费这个生成包。** 生成的根 `cjpm.toml` 把包名记为 `windows`（除非你用 `--package-name` / `--common` 改过），所以在你项目的 `cjpm.toml` 里这样写：

```toml
[dependencies]
  windows = { path = "../windows-cj/.generated/windows" }
```

然后在仓颉源码中按生成的命名空间导入。生成包按命名空间分成子包，例如 `Windows.Foundation` 会落在 `windows.Foundation` 子包下：

```cangjie
import windows.Foundation.*
```

> 范式提醒：仓颉的 import 是按**包名（下划线/点路径）**来写的。工作区里的稳定支持包目录与包名一致，也使用下划线；生成器会为输出包写好对应的路径依赖。

## 生成产物长什么样

一次典型的生成会写出这样一个目录结构：

```text
.generated/windows/
├── cjpm.toml                 # 包声明 + [dependencies]（指向所需的稳定支持包）
├── codegen-manifest.json     # 本次生成的清单（feature / 符号 / 文件 / 哈希）
└── src/
    ├── mod.cj                # 根包 package 声明
    ├── impl/                 # 真正的实现：vtable、native helper、类型渲染
    │   ├── mod.cj
    │   └── symbols_0.cj …    # 符号分块写入（每块约 512 个符号）
    └── Foundation/           # 按命名空间分出的对外 facade
        ├── mod.cj
        └── facade_0.cj …     # public type 别名，把 impl 里的实现暴露出去
```

设计上分成两层：`src/impl/` 放真正的实现细节，按符号数量切成 `symbols_N.cj` 多个块；命名空间目录（如 `Foundation/`）里则是 facade 文件，用 `public type` 别名把实现层的类型以稳定名字暴露给消费者。这样切分既控制了单个编译单元的大小，又给了你一个干净的对外表面。

### 它依赖哪些稳定支持包

生成包**不是自包含的**。生成器会扫描渲染结果用到了哪些底座类型，自动在 `cjpm.toml` 的 `[dependencies]` 里记下对应的稳定支持包路径依赖。常见的有：

| 支持包 | 何时被引入 |
| --- | --- |
| `windows_core` | 用到 COM/WinRT 底座、`Result`、接口宏时 |
| `windows_interface` | 用到 `@Interface` 宏、`GUID`、`IInspectable` 时 |
| `windows_polyfill` | 用到语言/标准库补齐 helper 时 |
| `windows_strings` | 用到 `HString` 等字符串类型时 |
| `windows_libloading` | 用到动态库加载（`LoadLibrary` 封装）时 |

也就是说，消费一个生成包时，这些它依赖的稳定支持包必须同时在你的工作区里可达——它们是生成代码能编译通过的前提。各包的职责见[包结构总览](packages.md)。

## 下一步 / 相关

- [包结构总览](packages.md)：搞清楚生成包依赖的那些稳定支持包各自负责什么。
- [WinUI 3 实战](winui3.md)：把生成的 WinUI 投影和 `windows_winui3` 支持包组合起来，跑出一个真正渲染的窗口。
