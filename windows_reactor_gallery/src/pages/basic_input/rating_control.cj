package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// RatingControl
// ============================================================================
let ratingControlPageToken = newComponentTypeToken()

func ratingControlPage(cx: RenderCx): Element {
    let (rating, setRating) = cx.useState<Float64>(3.0)

    page_content(
        "RatingControl",
        "A control that lets users provide a star rating.",
        [
            sample_card(
                "Basic RatingControl",
                vstack([
                    rating_control(rating)
                        .onChanged({ v: Float64 => setRating.call(v) })
                        .toElement(),
                    text_block("Rating: ${fmt1(rating)} / 5").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "rating_control(rating).onChanged(handler)"
            ),
            sample_card(
                "Custom Max Rating",
                rating_control(7.0)
                    .maxRatingOf(10)
                    .caption("Score out of 10")
                    .toElement(),
                "rating_control(7.0).maxRatingOf(10).caption(\"Score out of 10\")"
            ),
            sample_card(
                "Read-only Rating",
                rating_control(4.5)
                    .readOnly()
                    .caption("Average user rating")
                    .toElement(),
                "rating_control(4.5).readOnly().caption(\"Average\")"
            )
        ]
    )
}
