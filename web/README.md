# 文档站构建

安装 mdBook 后，从仓库根目录运行：

```console
python web/build.py
```

输出目录为 `web/book/book`，与 GitHub Pages 工作流一致。构建会为文档页面生成独立摘要、canonical、Open Graph、sitemap 和 robots.txt。新增章节时，在 `web/build.py` 的 `SUMMARIES` 中添加对应输出路径的摘要。

整本打印页、目录辅助页和 404 页面不进入 sitemap，并标记为不索引。
