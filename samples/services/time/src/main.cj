package windows_sample_time

import std.fs.{File, removeIfExists}
import windows_services.{Service, Command, ExtendedCommand}
import windows_sample_time_bindings.Win32.Foundation.{FILETIME, SYSTEMTIME}
import windows_sample_time_bindings.Win32.System.Services.{SERVICE_TIMECHANGE_INFO, Apis as ServicesApis}
import windows_sample_time_bindings.Win32.System.Time.Apis as TimeApis
import windows_sample_time_bindings.Win32.Storage.FileSystem.Apis as FileSystemApis

// ============================================================================
// time — behaviour-equivalent port of the reference sample.
//
// A Windows service that registers with the Service Control Manager (SCM)
// through the already-ported windows_services builder, declares it can stop and
// accepts SERVICE_ACCEPT_TIMECHANGE, and reacts to SERVICE_CONTROL_TIMECHANGE.
// On a time-change control it reinterprets the control's event data as a
// SERVICE_TIMECHANGE_INFO, converts the old/new FILETIME values to SYSTEMTIME
// via FileTimeToLocalFileTime + FileTimeToSystemTime, and appends everything to
// a log file so the conversion can be observed while the service runs.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference passes a `writeln!`-based closure capturing a `File`. The
//     equivalent here is a `(Service, Command) -> Unit` closure that appends a
//     line to the same log file. windows_services drives the SCM dispatcher and
//     invokes this closure on the @C service-control thunk for each command.
//   • The reference's `{command:?}` / `{data:#?}` / `{old:#?}` debug formatting
//     has no derive equivalent, so formatCommand / formatTimechange /
//     formatSystemTime reproduce the same observable textual shape.
//   • The reference's `&*(command.data as *const SERVICE_TIMECHANGE_INFO)` raw
//     reinterpret is mirrored by reinterpret-casting the @C struct pointer
//     (CPointer<Unit> -> CPointer<SERVICE_TIMECHANGE_INFO>) and reading it. The
//     event-data pointer is owned by the SCM and is only valid for the duration
//     of the control callback, matching the reference's borrow.
//   • The reference's `&time as *const i64 as _` passes a pointer to a stack i64
//     (a FILETIME is two u32 = one i64) into FileTimeToLocalFileTime. Here the
//     same is done by taking a CPointer to a local FILETIME/Int64 via `inout`
//     and reinterpreting it to CPointer<Unit>, exactly as the generated Apis
//     wrappers expect.
//   • `run` returns ServiceResult<Unit>. When the binary is launched outside the
//     SCM, StartServiceCtrlDispatcherW fails and `run` reports an error; we then
//     print the install/start/stop instructions, mirroring the reference's
//     `result.is_err()` shape.
// ============================================================================

// Log file the conversions are appended to, matching the reference's observable
// side effect (the reference uses "D:\\service.txt").
const LOG_PATH: String = "D:\\service.txt"

// Convert a FILETIME (packed as a single i64) to a local SYSTEMTIME, mirroring
// the reference's `convert`:
//     FileTimeToLocalFileTime(&time, &local); FileTimeToSystemTime(&local, &time)
func convert(time: Int64): SYSTEMTIME {
    var raw = time
    var local = FILETIME()
    var system = SYSTEMTIME()

    unsafe {
        let rawPtr = CPointer<Unit>(CPointer<Int64>(inout raw))
        let localPtr = CPointer<Unit>(CPointer<FILETIME>(inout local))
        FileSystemApis.FileTimeToLocalFileTime(rawPtr, localPtr)

        let localPtr2 = CPointer<Unit>(CPointer<FILETIME>(inout local))
        let systemPtr = CPointer<Unit>(CPointer<SYSTEMTIME>(inout system))
        TimeApis.FileTimeToSystemTime(localPtr2, systemPtr)
    }

    return system
}

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

// Reproduce the reference's `{data:#?}` debug shape for SERVICE_TIMECHANGE_INFO.
func formatTimechange(info: SERVICE_TIMECHANGE_INFO): String {
    "SERVICE_TIMECHANGE_INFO {\n" +
    "    liNewTime: ${info.liNewTime},\n" +
    "    liOldTime: ${info.liOldTime},\n" +
    "}"
}

// Reproduce the reference's `{time:#?}` debug shape for SYSTEMTIME.
func formatSystemTime(time: SYSTEMTIME): String {
    "SYSTEMTIME {\n" +
    "    wYear: ${time.wYear},\n" +
    "    wMonth: ${time.wMonth},\n" +
    "    wDayOfWeek: ${time.wDayOfWeek},\n" +
    "    wDay: ${time.wDay},\n" +
    "    wHour: ${time.wHour},\n" +
    "    wMinute: ${time.wMinute},\n" +
    "    wSecond: ${time.wSecond},\n" +
    "    wMilliseconds: ${time.wMilliseconds},\n" +
    "}"
}

main(): Int64 {
    // Truncate/create the log file up front so each run starts clean, matching
    // the reference's File::create.
    removeIfExists(LOG_PATH)
    let log = File.create(LOG_PATH)
    log.close()

    let result = Service.new()
        .canStop()
        .canAccept(ServicesApis.SERVICE_ACCEPT_TIMECHANGE)
        .run({ _service: Service, command: Command =>
            File.appendTo(LOG_PATH, "Command: ${formatCommand(command)}\n".toArray())

            match (command) {
                case Command.Extended(ext) where ext.control == ServicesApis.SERVICE_CONTROL_TIMECHANGE =>
                    let info = unsafe {
                        CPointer<SERVICE_TIMECHANGE_INFO>(ext.data).read()
                    }
                    File.appendTo(LOG_PATH, "${formatTimechange(info)}\n".toArray())

                    let old = convert(info.liOldTime)
                    let new = convert(info.liNewTime)

                    File.appendTo(
                        LOG_PATH,
                        "${formatSystemTime(old)}\n${formatSystemTime(new)}\n".toArray()
                    )
                case _ => ()
            }
        })

    if (result.isErr()) {
        println(
            "Use service control manager to start service.\n" +
            "\n" +
            "Install:\n" +
            "    > sc create ServiceName binPath= \"<path-to-exe>\"\n" +
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
