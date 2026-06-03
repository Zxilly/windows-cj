package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Dialogs and Flyouts category mod.
//
// Each control lives in its own file under this package (same directory = same
// package, so the page fns and their module-scope tokens are referenced here
// with default internal visibility). routeDialogs maps each Dialogs and Flyouts
// tag to its page component, wrapping each in pageComponent(token, fn) so the
// page owns an independent hook scope. One stable module-scope token per page is
// minted via newComponentTypeToken() in each control file.
//
//   tag                  page fn                    file
//   ------------------   -----------------------    ----------------------
//   command-bar-flyout   commandBarFlyoutPage       command_bar_flyout.cj
//   content-dialog       contentDialogPage          content_dialog.cj
//   flyout               flyoutPage                 flyout.cj
//   menu-flyout          menuFlyoutPage             menu_flyout.cj
//   teaching-tip         teachingTipPage            teaching_tip.cj
//
// The Button widget provides command-bar-flyout (commandBarFlyout /
// commandBarFlyoutSecondaryOf / onCommandBarFlyoutClick) and flyout(text)
// modifiers, so command-bar-flyout and flyout pop their popup from a button on
// click, matching the reference.
// ============================================================================

public func routeDialogs(tag: String): ?Element {
    match (tag) {
        case "command-bar-flyout" => Some(pageComponent(commandBarFlyoutPageToken, { cx: RenderCx => commandBarFlyoutPage(cx) }))
        case "content-dialog" => Some(pageComponent(contentDialogPageToken, { cx: RenderCx => contentDialogPage(cx) }))
        case "flyout" => Some(pageComponent(flyoutPageToken, { cx: RenderCx => flyoutPage(cx) }))
        case "menu-flyout" => Some(pageComponent(menuFlyoutPageToken, { cx: RenderCx => menuFlyoutPage(cx) }))
        case "teaching-tip" => Some(pageComponent(teachingTipPageToken, { cx: RenderCx => teachingTipPage(cx) }))
        case _ => None
    }
}
