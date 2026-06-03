package windows_reactor.core

// Rich-text paragraph model fed to the backend via setRichTextParagraphs and
// recorded by RecordingBackend. Pure data; structs with value equality.

public struct RichTextRun <: Equatable<RichTextRun> {
    public let text: String
    public let isBold: Bool
    public let isItalic: Bool
    public let isStrikethrough: Bool
    public let fontFamily: ?String
    public let fontSize: ?Float64

    public init(text: String, isBold: Bool, isItalic: Bool, isStrikethrough: Bool,
                fontFamily: ?String, fontSize: ?Float64) {
        this.text = text
        this.isBold = isBold
        this.isItalic = isItalic
        this.isStrikethrough = isStrikethrough
        this.fontFamily = fontFamily
        this.fontSize = fontSize
    }

    public static func plain(text: String): RichTextRun {
        RichTextRun(text, false, false, false, None, None)
    }

    public operator func ==(other: RichTextRun): Bool {
        text == other.text && isBold == other.isBold && isItalic == other.isItalic &&
        isStrikethrough == other.isStrikethrough &&
        optStrEq(fontFamily, other.fontFamily) && optF64Eq(fontSize, other.fontSize)
    }
    public operator func !=(other: RichTextRun): Bool { !(this == other) }
}

public struct RichTextHyperlink <: Equatable<RichTextHyperlink> {
    public let text: String
    public let uri: String
    public init(text: String, uri: String) {
        this.text = text
        this.uri = uri
    }
    public operator func ==(other: RichTextHyperlink): Bool {
        text == other.text && uri == other.uri
    }
    public operator func !=(other: RichTextHyperlink): Bool { !(this == other) }
}

public enum RichTextInline <: Equatable<RichTextInline> {
    | Run(RichTextRun)
    | LineBreak
    | Hyperlink(RichTextHyperlink)

    public operator func ==(other: RichTextInline): Bool {
        match ((this, other)) {
            case (Run(a), Run(b)) => a == b
            case (LineBreak, LineBreak) => true
            case (Hyperlink(a), Hyperlink(b)) => a == b
            case _ => false
        }
    }
    public operator func !=(other: RichTextInline): Bool { !(this == other) }
}

public struct RichTextParagraph <: Equatable<RichTextParagraph> {
    public let inlines: Array<RichTextInline>
    public init(inlines: Array<RichTextInline>) {
        this.inlines = inlines
    }
    public operator func ==(other: RichTextParagraph): Bool {
        arrayEq<RichTextInline>(inlines, other.inlines)
    }
    public operator func !=(other: RichTextParagraph): Bool { !(this == other) }
}
