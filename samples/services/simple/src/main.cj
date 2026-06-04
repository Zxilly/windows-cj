package windows_sample_simple

import std.fs.{File, removeIfExists}
import std.process.Process
import windows_services.{Service, Command, ExtendedCommand}

// ============================================================================
// simple — behaviour-equivalent port of the reference sample.
//
// A minimal Windows service. It registers with the Service Control Manager
// (SCM) through the already-ported windows_services builder and appends every
// control command it receives to a log file, so the commands can be observed
// while the service runs:
//
//     Service.new()
//         .canPause()    // accept PAUSE / CONTINUE
//         .canStop()     // accept STOP / SHUTDOWN
//         .run { _service, command => log "Command: <command>" }
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference passes a `writeln!`-based closure capturing a `File`. The
//     equivalent here is a `(Service, Command) -> Unit` closure that appends a
//     line to the same log file. windows_services drives the SCM dispatcher and
//     invokes this closure on the @C service-control thunk for each command.
//   • The reference's `{command:?}` debug formatting has no derive equivalent,
//     so `formatCommand` reproduces the same textual shape (Start / Stop /
//     Pause / Resume / Extended { control, ty }).
//   • `run` returns `ServiceResult<Unit>`. When the binary is launched outside
//     the SCM, `StartServiceCtrlDispatcherW` fails and `run` reports an error;
//     we then print the install/start/stop instructions, mirroring the
//     reference's `result.is_err()` branch.
//   • The reference's `std::env::current_exe()` is mirrored by
//     `Process.current.command`, the path used to launch this process.
// ============================================================================

// Log file the SCM control commands are appended to, matching the reference's
// observable side effect.
const LOG_PATH: String = "D:\\service.txt"

// Reproduce the reference's `{command:?}` debug shape for each Command variant.
func formatCommand(command: Command): String {
    match (command) {
        case Command.Start => "Start"
        case Command.Stop => "Stop"
        case Command.Pause => "Pause"
        case Command.Resume => "Resume"
        case Command.Extended(ext) =>
            "Extended { control: ${ext.control}, ty: ${ext.ty} }"
    }
}

main(): Int64 {
    // Truncate/create the log file up front so each run starts clean, matching
    // the reference's File::create.
    removeIfExists(LOG_PATH)
    let log = File.create(LOG_PATH)
    log.close()

    let result = Service.new()
        .canPause()
        .canStop()
        .run({ _service: Service, command: Command =>
            let line = "Command: ${formatCommand(command)}\n"
            File.appendTo(LOG_PATH, line.toArray())
        })

    if (result.isErr()) {
        let exePath = Process.current.command
        println(
            "Use service control manager to start service.\n" +
            "\n" +
            "Install:\n" +
            "    > sc create ServiceName binPath= \"${exePath}\"\n" +
            "\n" +
            "Start:\n" +
            "    > sc start ServiceName\n" +
            "\n" +
            "Query status:\n" +
            "    > sc query ServiceName\n" +
            "\n" +
            "Stop:\n" +
            "    > sc stop ServiceName\n" +
            "\n" +
            "Delete (uninstall):\n" +
            "    > sc delete ServiceName\n"
        )
    }

    return 0
}
