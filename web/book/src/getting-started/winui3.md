# WinUI 3 实战

前面几章你调用过 Win32、消费过 COM、投影过 WinRT。本章把这些能力组合到一起，目标很具体：**用 windows-cj 跑起一个真正渲染的 WinUI 3 窗口**。

WinUI 3 不是普通的 Win32 窗口。它运行在 Windows App SDK 之上，需要先用 bootstrap 机制把 App SDK 运行时挂载进进程，再初始化 COM 套间，最后通过 `Application.Start` 把控制权交给 XAML 框架。下面我们严格按照一个已经跑通的 demo（`windows-cj-demo`）走一遍这套启动序列。

## 支持包：windows-winui3

你不需要手写这套 ABI 胶水。`windows-winui3` 是一个**只面向运行时**的支持包，它把 WinUI 3 / Windows App SDK 的启动逻辑封装成了三个子模块：

- `windows_winui3.appsdk` —— 挂载/卸载 Windows App SDK 运行时（bootstrap）。
- `windows_winui3.win32` —— 初始化/反初始化 COM 套间。
- `windows_winui3.xaml` —— `ApplicationCallback`、`WindowHandle`、`startApplication`，以及加载 XAML、接线按钮事件用的可复用句柄。

在你项目源码里这样导入（与 demo 一致）：

```cangjie
import windows_winui3.appsdk
import windows_winui3.win32
import windows_winui3.xaml.{ApplicationCallback, WindowHandle, startApplication}
```

## 启动序列

整个 `main` 的骨架是：**挂载 App SDK → 初始化 COM 套间 → 启动应用（创建并激活窗口）→ 在 `finally` 中逐层清理**。下面逐段拆解，代码取自 `windows-cj-demo/src/main.cj`。

### 第一步：找到 bootstrap DLL 并挂载 App SDK

WinUI 3 的运行时不在系统目录里，需要你提供 Windows App SDK 的 bootstrap DLL（`Microsoft.WindowsAppRuntime.Bootstrap.dll`）的路径。demo 优先读环境变量 `WINDOWS_APPSDK_BOOTSTRAP_DLL`，读不到再回落到本地 NuGet 缓存里的候选路径：

```cangjie
func bootstrapDllPath(): String {
    match (getVariable("WINDOWS_APPSDK_BOOTSTRAP_DLL")) {
        case Some(path) =>
            if (!path.isEmpty()) {
                return path
            }
        case None => ()
    }

    for (candidate in LOCAL_BOOTSTRAP_DLL_CANDIDATES) {
        if (exists(candidate)) {
            return canonicalize(candidate).toString()
        }
    }
    return ""
}
```

> 范式提醒：环境变量读出来是 `Option<String>`，不是会抛 `null` 的字符串——用 `match` 解构 `Some` / `None`，这是仓颉处理“可能不存在”的标准方式。

拿到路径后，把它交给 `appsdk.initialize`。它返回一个 `HRESULT`；用 `.failed()` 判断是否失败（而不是去比较某个魔数）：

```cangjie
let bootstrapPath = bootstrapDllPath()

let appSdkHr = appsdk.initialize(bootstrapDllPath: bootstrapPath)
if (appSdkHr.failed()) {
    eprintln("[demo] Windows App SDK initialization failed: ${appSdkHr}")
    return 1
}
```

注意 `bootstrapDllPath:` 是一个**命名参数**——`initialize` 的签名是 `initialize(bootstrapDllPath!: String = "")`，调用时要带上参数名。

### 第二步：初始化 COM 套间

WinUI 3 是 COM/WinRT 之上的框架，必须先初始化一个套间。`win32.initializeApartmentThreaded()` 底层就是以 `COINIT_APARTMENTTHREADED` 调用 `CoInitializeEx`，同样返回 `HRESULT`：

```cangjie
let comHr = win32.initializeApartmentThreaded()
if (comHr.failed()) {
    eprintln("[demo] CoInitializeEx STA failed: ${comHr}")
    appsdk.shutdown()
    return 1
}
```

如果套间初始化失败，要记得把上一步已经挂载的 App SDK 卸载掉（`appsdk.shutdown()`），再退出。

### 第三步：启动应用，创建并激活窗口

WinUI 3 的入口是 `Application.Start`：你把一段回调交给框架，框架在内部把 XAML 运行时准备好之后，回调到你这里，你才能创建窗口和 UI。

在 windows-cj 里，这段回调用 `ApplicationCallback({ => ... })` 包装——一个**无参闭包**（`{ => ... }`），里面创建 `WindowHandle`、装入内容、`show()`、`activate()`，最后用 `startApplication(callback)` 把回调投递给框架：

```cangjie
func startWinui(): Unit {
    let callback = ApplicationCallback({ =>
        let window = WindowHandle.create()
        let app = TodoApp.createInitial(window)

        app.show()
        window.activate()

        // 把句柄挂到全局根上，避免被 GC 提前回收，留待 finally 清理
        todoAppRoot = Some(app)
        windowRoot = Some(window)
    })
    applicationCallbackRoot = Some(callback)
    startApplication(callback)
}
```

这里的关键 API：

- `WindowHandle.create()` —— 通过 WinRT 激活工厂创建一个 `Window`，返回一个 `WindowHandle`（实现了 `Resource`）。
- `WindowHandle.activate()` —— 调用底层 `IWindow.Activate`，把窗口显示出来。
- `window.setTitle(...)` / `window.setContent(...)` —— 设置标题与内容（demo 的 `TodoApp.show()` 内部会调用它们，通过 `UIElementHandle.loadXaml(...)` 把一段 XAML 字符串解析成可挂载的 UI 元素）。

> 范式提醒：当这段代码看起来与你在其它语言里的写法不同时，多半是因为它遵循了仓颉的范式。这里的 `{ => ... }` 就是仓颉的无参 lambda——没有参数也不能省略 `=>`。

### 第四步：在 finally 中逐层清理

启动流程包在 `try` 里，无论成功还是抛异常，都要在 `finally` 中把资源还回去——顺序是与申请相反的：先关 WinUI 句柄，再反初始化套间，最后卸载 App SDK。

```cangjie
var exitCode: Int64 = 0
try {
    startWinui()
} catch (err: Exception) {
    eprintln("[demo] WinUI startup failed: ${err}")
    exitCode = 1
} finally {
    cleanupGeneratedWinuiRoots()
    win32.uninitializeApartment()
    appsdk.shutdown()
}
return exitCode
```

## 资源生命周期

`ApplicationCallback`、`WindowHandle`、以及你自己的应用对象（demo 里的 `TodoApp`，它本身 `<: Resource`）都持有原生 COM 指针。仓颉的 GC 会管理仓颉对象之间的引用，但**原生指针必须显式释放**——这就是这些类型都实现 `Resource` 并提供 `close()` 的原因。

demo 的 `cleanupGeneratedWinuiRoots` 演示了正确的关闭顺序：先关应用、再关窗口、最后关回调，每一步都先 `match` 出 `Option` 里的句柄，关掉后把根置回 `None`：

```cangjie
func cleanupGeneratedWinuiRoots(): Unit {
    match (todoAppRoot) {
        case Some(app) => app.close()
        case None => ()
    }
    match (windowRoot) {
        case Some(window) => window.close()
        case None => ()
    }
    match (applicationCallbackRoot) {
        case Some(callback) => callback.close()
        case None => ()
    }
    applicationCallbackRoot = None
    windowRoot = None
    todoAppRoot = None
}
```

为什么不靠 GC 的析构器（`~init`）自动释放？因为原生 COM 资源的释放时机是确定性的，不能等 GC 不确定何时跑。这些句柄内部都带了一个 `closed: Bool` 回收标记，保证 `close()` 和析构器不会对同一个原生指针重复释放（double free）。**规则很简单：你创建的每个句柄，都要在退出路径上 `close()`。**

## cjpm.toml

demo 的包配置（取自 `windows-cj-demo/cjpm.toml`）：

```toml
[package]
  name = "windows_cj_demo"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"
  compile-option = "-Woff unused -Woff package-import"
  link-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_winui3 = { path = "../windows-cj/windows-winui3" }
```

两点值得注意：

- `output-type = "executable"` —— 这是一个可执行程序，不是库。
- `link-option = "-lole32 -loleaut32 -lwindowsapp"` —— COM/WinRT 需要链接这几个系统库。`cjpm` **不会**把静态依赖里的 native `link-option` 向上传播给根可执行文件，所以即便 `windows_winui3` 是个静态依赖，根项目仍要在自己的 `cjpm.toml` 里把这些导入库写全。

## 构建与运行

在 demo 目录下构建。工作区级别的编译建议把 GC 堆上限调高，避免 OOM：

```powershell
$env:cjHeapSize = '32GB'
cjpm build
```

然后用 `cjv exec` 运行产物（**不要直接裸跑 `.exe`**，否则可能链接不到正确的仓颉运行时）：

```powershell
cjv exec .\target\release\bin\windows_cj_demo.exe
```

> 运行前提：你的机器上必须有 **Windows App SDK 运行时**，且程序能找到它的 bootstrap DLL。最省事的方式是设置环境变量指定路径：
>
> ```powershell
> $env:WINDOWS_APPSDK_BOOTSTRAP_DLL = 'C:\path\to\Microsoft.WindowsAppRuntime.Bootstrap.dll'
> ```
>
> 不设的话，demo 会回落去本地 NuGet 缓存里找候选路径——找不到就拿不到 App SDK，窗口起不来。

跑通后，你会看到一个真正渲染的 WinUI 3 窗口。至此，你已经把 Win32 套间初始化、WinRT 激活工厂、COM 接口调用、以及确定性资源回收全部串了起来。

## 下一步 / 相关

- [调用 WinRT API](winrt-api.md)：深入 WinUI 背后的 WinRT 投影机制——激活工厂、`IInspectable`、运行时类。
- [引言](readme.md)：回到全书入口，按需挑选其它主题。
