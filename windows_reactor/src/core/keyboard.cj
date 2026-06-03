package windows_reactor.core

// Keyboard accelerator data carried on Modifiers.keyboardAccelerators.

// Bit-flags subset of WinRT VirtualKeyModifiers.
public struct KeyModifiers <: Equatable<KeyModifiers> {
    public let bits: UInt32
    public init(bits: UInt32) { this.bits = bits }

    public static let NONE = KeyModifiers(0)
    public static let CONTROL = KeyModifiers(1)
    public static let ALT = KeyModifiers(2)
    public static let SHIFT = KeyModifiers(4)
    public static let WINDOWS = KeyModifiers(8)

    public func contains(other: KeyModifiers): Bool {
        (bits & other.bits) == other.bits
    }
    public func isEmpty(): Bool { bits == 0 }

    public operator func |(rhs: KeyModifiers): KeyModifiers { KeyModifiers(bits | rhs.bits) }
    public operator func ==(other: KeyModifiers): Bool { bits == other.bits }
    public operator func !=(other: KeyModifiers): Bool { bits != other.bits }
}

public enum KeyboardKey <: Equatable<KeyboardKey> {
    | A | B | C | D | E | F | G | H | I | J | K | L | M | N | O | P | Q | R | S
    | T | U | V | W | X | Y | Z
    | Num0 | Num1 | Num2 | Num3 | Num4 | Num5 | Num6 | Num7 | Num8 | Num9
    | NumPad0 | NumPad1 | NumPad2 | NumPad3 | NumPad4 | NumPad5 | NumPad6
    | NumPad7 | NumPad8 | NumPad9
    | NumPadAdd | NumPadSubtract | NumPadMultiply | NumPadDivide | NumPadDecimal
    | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 | F9 | F10 | F11 | F12
    | Enter | Escape | Tab | Space | Backspace | Delete | Insert
    | Home | End | PageUp | PageDown | Left | Right | Up | Down

    public func tag(): Int64 {
        match (this) {
            case A => 0
            case B => 1
            case C => 2
            case D => 3
            case E => 4
            case F => 5
            case G => 6
            case H => 7
            case I => 8
            case J => 9
            case K => 10
            case L => 11
            case M => 12
            case N => 13
            case O => 14
            case P => 15
            case Q => 16
            case R => 17
            case S => 18
            case T => 19
            case U => 20
            case V => 21
            case W => 22
            case X => 23
            case Y => 24
            case Z => 25
            case Num0 => 26
            case Num1 => 27
            case Num2 => 28
            case Num3 => 29
            case Num4 => 30
            case Num5 => 31
            case Num6 => 32
            case Num7 => 33
            case Num8 => 34
            case Num9 => 35
            case NumPad0 => 36
            case NumPad1 => 37
            case NumPad2 => 38
            case NumPad3 => 39
            case NumPad4 => 40
            case NumPad5 => 41
            case NumPad6 => 42
            case NumPad7 => 43
            case NumPad8 => 44
            case NumPad9 => 45
            case NumPadAdd => 46
            case NumPadSubtract => 47
            case NumPadMultiply => 48
            case NumPadDivide => 49
            case NumPadDecimal => 50
            case F1 => 51
            case F2 => 52
            case F3 => 53
            case F4 => 54
            case F5 => 55
            case F6 => 56
            case F7 => 57
            case F8 => 58
            case F9 => 59
            case F10 => 60
            case F11 => 61
            case F12 => 62
            case Enter => 63
            case Escape => 64
            case Tab => 65
            case Space => 66
            case Backspace => 67
            case Delete => 68
            case Insert => 69
            case Home => 70
            case End => 71
            case PageUp => 72
            case PageDown => 73
            case Left => 74
            case Right => 75
            case Up => 76
            case Down => 77
        }
    }

    public operator func ==(other: KeyboardKey): Bool { tag() == other.tag() }
    public operator func !=(other: KeyboardKey): Bool { tag() != other.tag() }
}

// A single keyboard shortcut bound to an element. Identity of the callback is
// used for equality (the on_invoked closure is opaque) so re-renders with the
// same handler do not force re-binding.
public class KeyboardAccelerator {
    public let key: KeyboardKey
    public let modifiers: KeyModifiers
    public let onInvoked: Callback<Unit>

    public init(key: KeyboardKey, modifiers: KeyModifiers, onInvoked: Callback<Unit>) {
        this.key = key
        this.modifiers = modifiers
        this.onInvoked = onInvoked
    }

    public func equals(other: KeyboardAccelerator): Bool {
        key == other.key && modifiers == other.modifiers && onInvoked.sameAs(other.onInvoked)
    }
}
