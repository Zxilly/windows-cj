# 引言

**windows-cj** 是一套用 [仓颉（Cangjie）](https://cangjie-lang.cn/) 编写的 Windows API 绑定与投影。它让你能够直接在仓颉中调用 Win32、COM 与 WinRT 接口，覆盖从底层 C 风格函数到现代 WinRT 运行时类的完整谱系，并尽量提供符合仓颉习惯、安全易用的编程模型。

这套库以一组相互独立、各司其职的包组织起来：字符串、错误码、COM 接口实现、WinRT 集合与异步、WinUI 3 支持，以及在编译期之外按需生成绑定的 `windows-bindgen` 工具。你可以只依赖其中一小部分，也可以把它们组合起来构建完整的桌面应用。

## 本书面向谁

- **熟悉 Windows、初次接触仓颉的开发者**：你已经了解 `HRESULT`、`IUnknown::QueryInterface`、WinRT 激活工厂这些概念，本书帮你把它们映射到仓颉的类型系统与内存模型上。
- **熟悉仓颉、初次接触 Windows 的开发者**：你习惯了仓颉的 `Option<T>`、`class`/`struct` 语义和 GC，本书帮你理解 Windows ABI 在这些范式下是如何落地的。

## 关于「行为等价」

windows-cj 的设计目标是与原生 Windows ABI **行为等价**——相同的输入产生相同的 Win32 / WinRT ABI 效果——而不是照搬其它语言的 API 表面。**仓颉是 GC 语言**，因此你不会在这里看到借用、所有权、生命周期标注这类概念：

- 仓颉对象之间的引用由 GC 管理，无需手动 `AddRef` / `Release`。
- 持有原生 COM 指针的类型实现 `Resource` 接口，配合 `try-with-resource` 或析构器回收。
- `Option<T>` 取代了空指针；没有 `null` 关键字。

阅读本书时请记住这一点：当某段代码看起来与你在其它语言里的写法不同时，多半是因为它遵循了仓颉的范式，而非缺失了功能。

## 如何阅读

建议从 [概述](getting-started/readme.md) 开始，按顺序读完 [安装与环境配置](getting-started/installation.md) 和 [包结构总览](getting-started/packages.md)，再根据需要跳转到具体主题——调用 Win32、处理字符串、实现 COM 接口、消费 WinRT、生成绑定，直到最后的 [WinUI 3 实战](getting-started/winui3.md)。

## 相关链接

- [windows-cj 源码仓库](https://github.com/Zxilly/windows-cj)
- [仓颉编程语言官网](https://cangjie-lang.cn/)
- [仓颉官方文档](https://cangjie-lang.cn/docs)
