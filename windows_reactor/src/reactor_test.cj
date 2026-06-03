package windows_reactor

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testElementAndBasicFactories() {
    let thickness = Thickness.uniform(4.0)
    @Expect(thickness.left, 4.0)
    @Expect(thickness.top, 4.0)
    @Expect(Modifiers().is_empty(), true)
    @Expect(Element.Empty.key().isNone(), true)

    let first = Element.textBlock(text_block("x"))
    let second = Element.textBlock(text_block("y"))
    let third = Element.button(button("z"))
    @Expect(first.kind_matches(second), true)
    @Expect(first.kind_matches(third), false)
    @Expect(first.kind_name(), "TextBlock")
}

@Test
func testBuilders() {
    let text = text_block("hello").bold().font_size(28.0)
    @Expect(text.fontWeight, Some(700))
    @Expect(text.fontSize, Some(28.0))

    let action = button("go").on_click({ => () }).enabled(false)
    @Expect(action.isEnabled, false)
    @Expect(action.onClick.isSome(), true)

    let panel = vstack([Element.textBlock(text_block("a")), Element.button(button("b"))]).spacing(8.0)
    @Expect(panel.vertical, true)
    @Expect(panel.children.size, 2)
    @Expect(panel.spacingValue, Some(8.0))

    let combo = combo_box(["Red", "Green", "Blue"]).selected_index(1)
    @Expect(combo.items.size, 3)
    @Expect(combo.selectedIndex, 1)
}

@Test
func testFormWidgetsDefaults() {
    @Expect(password_box().revealMode, PasswordRevealMode.Peek)
    @Expect(password_box().isEnabled, true)
    @Expect(radio_buttons(["A", "B"]).selectedIndex, -1)

    let picture = person_picture().display_name("Ada Lovelace").initials("AL")
    @Expect(picture.displayName, Some("Ada Lovelace"))
    @Expect(picture.initialsValue, Some("AL"))
}

@Test
func testCustomControlKeepsUnknownControlIdentity() {
    let custom = custom_control("NavigationView")
        .property("paneDisplayMode", "Left")
        .child(Element.textBlock(text_block("Home")))

    @Expect(custom.controlKind(), ControlKind.Custom)
    @Expect(custom.properties.size, 1)
    @Expect(custom.childrenValue.size, 1)
    @Expect(Element.custom(custom).kind_name(), "NavigationView")
}
