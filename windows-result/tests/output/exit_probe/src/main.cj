package exit_probe
import std.env.*
main(): Unit {
    eprintln("probe")
    exit(3)
}