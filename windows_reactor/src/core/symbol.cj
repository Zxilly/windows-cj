package windows_reactor.core

// Symbol icon matching the WinUI Symbol enum. Used by command bar buttons,
// navigation view items, selector bar items, and any widget with an icon slot.
public enum SymbolGlyph <: Equatable<SymbolGlyph> {
    | Add | Delete | Edit | Save | Cancel | Accept | More | Redo | Undo | Home
    | Back | Forward | Favorite | Camera | Setting | Find | Help | Mail | Send
    | Copy | Cut | Paste | Play | Pause | Download | Upload | Sync | People
    | Flag | World | Brightness | ClearNight

    public func toRaw(): Int32 {
        match (this) {
            case Add => 57609
            case Delete => 57607
            case Edit => 57604
            case Save => 57605
            case Cancel => 57610
            case Accept => 57611
            case More => 57612
            case Redo => 57613
            case Undo => 57614
            case Home => 57615
            case Back => 57618
            case Forward => 57617
            case Favorite => 57619
            case Camera => 57620
            case Setting => 57621
            case Find => 57626
            case Help => 57627
            case Mail => 57625
            case Send => 57634
            case Copy => 57711
            case Cut => 57710
            case Paste => 57709
            case Play => 57602
            case Pause => 57603
            case Download => 57624
            case Upload => 57628
            case Sync => 57623
            case People => 57637
            case Flag => 57641
            case World => 57640
            case Brightness => 0xE706
            case ClearNight => 0xE708
        }
    }

    public operator func ==(other: SymbolGlyph): Bool { toRaw() == other.toRaw() }
    public operator func !=(other: SymbolGlyph): Bool { toRaw() != other.toRaw() }
}
