# 文档站构建

安装 mdBook 0.5.4 和 mdbook-sitemap 0.1.1 后，从仓库根目录运行：

```console
cargo install mdbook-sitemap --version 0.1.1 --locked
python web/build.py
```

发布目录为 `web/book/book/html`，与 GitHub Pages 工作流一致。`mdbook-sitemap` 后端根据章节结构生成 `web/book/book/sitemap/sitemap.xml`；`web/build.py` 只把其中的 `index.html` 转换为对应目录 canonical，并复制到发布目录。插件关闭 `include-lastmod`，避免把构建日期误当作页面修改日期。

构建仍为文档页面补充独立摘要、canonical、Open Graph 和 robots.txt。新增章节时，在 `web/build.py` 的 `SUMMARIES` 中添加对应输出路径的摘要，sitemap 由插件自动更新。

整本打印页、目录辅助页和 404 页面不进入 sitemap，并标记为不索引。
