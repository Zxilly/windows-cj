"""Build the documentation with canonical URLs, page summaries and a sitemap."""

from html import escape, unescape
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

SITE = "https://windows.cj.zxilly.dev"
ROOT = Path(__file__).resolve().parent
SUMMARIES = {
    "index.html": "使用 windows-cj 在仓颉中调用 Windows API。了解 Win32、COM、WinRT 和 WinUI 3 的入门路径、绑定生成与支持包。",
    "getting-started/index.html": "了解 windows-cj 的 Win32、COM 和 WinRT 三层 API，以及各层对应的仓颉支持包与入门顺序。",
    "getting-started/installation.html": "配置 windows-cj 的 Windows 开发环境，安装仓颉工具链并了解原生 ABI、依赖与运行环境要求。",
    "getting-started/packages.html": "按职责查找 windows-cj 的基础类型、Win32、COM、WinRT 和 WinUI 支持包，为仓颉项目选择所需依赖。",
    "getting-started/first-win32-api.html": "用仓颉调用第一个 Win32 API，理解系统 DLL 函数、句柄、指针参数和返回码，并正确管理原生资源。",
    "getting-started/strings.html": "在仓颉与 Windows API 之间转换 UTF-8 和 UTF-16 字符串，选择 PCWSTR、CWideString、HSTRING 等合适的表示。",
    "getting-started/error-handling.html": "在 windows-cj 中处理 HRESULT、Win32 错误码和 NTSTATUS，使用 windows_result 进行错误检查、传播和异常处理。",
    "getting-started/com-api.html": "在仓颉中调用 COM 接口、查询其他接口，并了解 vtable ABI 与原生 COM 指针的生命周期管理。",
    "getting-started/implement-com.html": "使用 windows_interface 在仓颉中实现 COM 接口，让系统或其他 COM 组件通过接口回调仓颉对象。",
    "getting-started/winrt-api.html": "通过 windows-cj 在仓颉中调用 WinRT API，理解运行时类、激活工厂、IInspectable 和 HSTRING 的使用。",
    "getting-started/collections.html": "使用 windows_collections 在仓颉中遍历和创建 WinRT 集合，并将仓颉数据提供给 Windows 集合接口。",
    "getting-started/async.html": "通过 windows_future 处理 WinRT 异步操作，理解完成回调、状态与进度，以及 join 和 when 的用法。",
    "getting-started/bindgen.html": "使用 windows_bindgen 读取 Windows 元数据并生成仓颉绑定，按 feature 选择 API，再通过路径依赖接入项目。",
    "getting-started/narrow-bindings.html": "按应用实际使用的 Windows 类型裁剪仓颉绑定，生成更小的 windows_sys 包，减少不需要的类型与二进制体积。",
    "getting-started/winui3.html": "使用 windows-cj 构建仓颉 WinUI 3 窗口，配置 Windows App SDK、bootstrap、COM 初始化和 XAML 启动流程。",
}


def main():
    subprocess.run(["mdbook", "build", str(ROOT / "book")], check=True)
    output = ROOT / "book" / "book" / "html"
    for page in sorted(output.rglob("*.html")):
        source = page.read_text(encoding="utf-8")
        relative = page.relative_to(output).as_posix()
        if page.name in {"404.html", "print.html", "toc.html"} or re.search(r'http-equiv=["\']refresh', source, re.I):
            source = source.replace("</head>", '<meta name="robots" content="noindex,follow">\n</head>')
        else:
            description = SUMMARIES.get(relative)
            if not description:
                raise ValueError(f"Add a page summary for {relative}")
            title = unescape(re.search(r"<title>(.*?)</title>", source, re.S)[1])
            path = relative.removesuffix("index.html") if page.name == "index.html" else relative
            canonical = SITE + "/" + path
            source = re.sub(r'<meta name="description"[^>]*>', "", source)
            tags = [f'<link rel="canonical" href="{escape(canonical, quote=True)}">',
                    f'<meta name="description" content="{escape(description, quote=True)}">']
            for prop, value in {"og:type": "article", "og:site_name": "windows-cj", "og:title": title,
                                "og:description": description, "og:url": canonical, "og:locale": "zh_CN"}.items():
                tags.append(f'<meta property="{prop}" content="{escape(value, quote=True)}">')
            source = source.replace("</head>", "\n".join(tags) + "\n</head>")
        page.write_text(source, encoding="utf-8")
    # mdbook-sitemap owns chapter discovery and XML generation. Match the
    # published directory canonicals without changing the plugin's URL list.
    ET.register_namespace("", "http://www.sitemaps.org/schemas/sitemap/0.9")
    sitemap = ET.parse(output.parent / "sitemap" / "sitemap.xml")
    locations = sitemap.findall(".//{*}loc")
    for location in locations:
        location.text = location.text.removesuffix("index.html")
    sitemap.write(output / "sitemap.xml", encoding="utf-8", xml_declaration=True)
    (output / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n", encoding="utf-8")
    print(f"Added metadata and canonical paths to {len(locations)} plugin sitemap URLs.")


if __name__ == "__main__":
    main()
