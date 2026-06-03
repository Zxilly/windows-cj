package windows_reactor_gallery

import windows_reactor.winui.{App, Backdrop, reexecWithUiStackIfNeeded}

// ============================================================================
// Reactor WinUI Gallery — process entry. Builds the App and renders the shell.
// ============================================================================

main(): Int64 {
    // Ensure the UI cjthread has a large enough stack for deep WinUI render frames.
    // If cjStackSize is unset (e.g. the packaged exe launched directly), this
    // re-launches self with it set and returns the child's exit code; otherwise a
    // no-op. See reexecWithUiStackIfNeeded.
    match (reexecWithUiStackIfNeeded()) {
        case Some(code) => return code
        case None => ()
    }

    App.new()
        .title("Reactor WinUI Gallery")
        .inner_size(1400.0, 900.0)
        .backdrop(Backdrop.Mica)
        .eager_templated_realization(true)
        .render(gallery_shell)
    0
}
