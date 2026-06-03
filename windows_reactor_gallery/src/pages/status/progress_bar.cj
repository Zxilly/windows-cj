package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── ProgressBar ──────────────────────────────────────────────────────────────

let progressBarPageToken = newComponentTypeToken()

func progress_bar_page(): Element {
    pageComponent(progressBarPageToken, { cx: RenderCx =>
        let (value, setValue) = cx.useState<Float64>(60.0)
        let (loading, setLoading) = cx.useState<Bool>(true)

        let indeterminateSample: Element = if (loading) {
            ProgressBar.indeterminate().width(300.0).toElement()
        } else {
            progress_bar(100.0).width(300.0).toElement()
        }

        page_content(
            "ProgressBar",
            "A horizontal bar that shows progress of an operation.",
            [
                sample_card(
                    "Determinate ProgressBar",
                    vstack([
                        progress_bar(value).width(300.0).toElement(),
                        text_block("Progress: ${percent0(value)}%").opacity(0.6).toElement(),
                        slider(value)
                            .range(0.0, 100.0)
                            .onChanged({ v: Float64 => setValue.call(v) })
                            .width(300.0)
                            .toElement()
                    ]).spacing(8.0).toElement(),
                    "progress_bar(value).width(300.0)\nslider(value).range(0.0, 100.0).onChanged(handler)"
                ),
                sample_card(
                    "Indeterminate ProgressBar",
                    vstack([
                        indeterminateSample,
                        toggle_switch(loading)
                            .onContentText("Loading")
                            .offContentText("Complete")
                            .onChanged({ v: Bool => setLoading.call(v) })
                            .toElement()
                    ]).spacing(8.0).toElement(),
                    "if (loading) {\n    ProgressBar.indeterminate()\n} else {\n    progress_bar(100.0)\n}"
                )
            ]
        )
    })
}
