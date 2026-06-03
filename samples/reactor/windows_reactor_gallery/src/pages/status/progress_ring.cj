package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── ProgressRing ─────────────────────────────────────────────────────────────

let progressRingPageToken = newComponentTypeToken()

func progress_ring_page(): Element {
    pageComponent(progressRingPageToken, { cx: RenderCx =>
        let (value, setValue) = cx.useState<Float64>(75.0)

        page_content(
            "ProgressRing",
            "A circular indicator of ongoing progress.",
            [
                sample_card(
                    "Indeterminate ProgressRing",
                    ProgressRing.indeterminate().toElement(),
                    "ProgressRing.indeterminate()"
                ),
                sample_card(
                    "Determinate ProgressRing",
                    vstack([
                        progress_ring(value).toElement(),
                        slider(value)
                            .range(0.0, 100.0)
                            .onChanged({ v: Float64 => setValue.call(v) })
                            .toElement(),
                        text_block("${percent0(value)}%").opacity(0.6).toElement()
                    ]).spacing(8.0).toElement(),
                    "progress_ring(value) // controlled by slider"
                )
            ]
        )
    })
}
