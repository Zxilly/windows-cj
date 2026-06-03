package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// PasswordBox
// ============================================================================
let passwordBoxPageToken = newComponentTypeToken()

func passwordBoxPage(cx: RenderCx): Element {
    let (password, setPassword) = cx.useState<String>("")

    page_content(
        "PasswordBox",
        "A text input that conceals typed characters for secure entry.",
        [
            sample_card(
                "Basic PasswordBox",
                vstack([
                    password_box()
                        .valueOf(password)
                        .header("Password")
                        .placeholder("Enter password")
                        .onChanged({ s: String => setPassword.call(s) })
                        .toElement(),
                    text_block("Length: ${password.size} chars").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "password_box().header(\"Password\").placeholder(\"...\").onChanged(handler)"
            ),
            sample_card(
                "PasswordBox with Reveal Button",
                password_box()
                    .header("Secret Key")
                    .placeholder("Enter secret")
                    .revealButtonEnabled(true)
                    .toElement(),
                "password_box().revealButtonEnabled(true)"
            ),
            sample_card(
                "Disabled PasswordBox",
                password_box()
                    .valueOf("hunter2")
                    .header("Saved")
                    .enabled(false)
                    .toElement(),
                "password_box().valueOf(\"***\").enabled(false)"
            )
        ]
    )
}
