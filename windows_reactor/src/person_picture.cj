package windows_reactor

public class PersonPicture <: Widget {
    public var displayName: Option<String> = None
    public var initialsValue: Option<String> = None
    public var modifiers: Modifiers = Modifiers()

    public init() {}

    public static func new(): PersonPicture {
        PersonPicture()
    }

    public func controlKind(): ControlKind { ControlKind.PersonPicture }
    public func toElement(): Element { Element.personPicture(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = frameworkAttrs(modifiers)
        match (displayName) {
            case Some(name) => attrs += attr("DisplayName", name)
            case None => ()
        }
        match (initialsValue) {
            case Some(initials) => attrs += attr("Initials", initials)
            case None => ()
        }
        "<PersonPicture" + attrs + " />"
    }

    public func display_name(value: String): PersonPicture {
        displayName = Some(value)
        this
    }

    public func initials(value: String): PersonPicture {
        initialsValue = Some(value)
        this
    }

    public func name(value: String): PersonPicture {
        modifiers.xName = Some(value)
        this
    }
}

public func person_picture(): PersonPicture { PersonPicture.new() }
