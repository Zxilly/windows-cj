package windows_result

func originateError(code: HRESULT, message: String): Bool {
    let units = encodeUtf16Units(message)
    if (units.isEmpty()) {
        return false
    }

    unsafe {
        let handle = acquireArrayRawData(units)
        try {
            roOriginateErrorWAbi(code.value, UInt32(units.size), handle.pointer) != 0i32
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func captureDescription(raw: CPointer<IErrorInfo>): Option<String> {
    if (raw.isNull()) {
        return None
    }

    var descriptionPtr = CPointer<UInt16>()
    let hr = unsafe {
        let info = raw.read()
        let vtbl = info.lpVtbl.read()
        HRESULT(vtbl.GetDescription(CPointer<Unit>(raw), CPointer<CPointer<UInt16>>(inout descriptionPtr)))
    }
    if (hr.failed()) {
        return None
    }

    let description = BasicString.fromRaw(descriptionPtr)
    try {
        Some(description.toString())
    } finally {
        description.close()
    }
}

func captureRestrictedDescription(raw: CPointer<IRestrictedErrorInfo>): Option<String> {
    if (raw.isNull()) {
        return None
    }

    var fallbackPtr = CPointer<UInt16>()
    var errorCode = 0i32
    var descriptionPtr = CPointer<UInt16>()
    var referencePtr = CPointer<UInt16>()

    let hr = unsafe {
        let info = raw.read()
        let vtbl = info.lpVtbl.read()
        HRESULT(
            vtbl.GetErrorDetails(
                CPointer<Unit>(raw),
                CPointer<CPointer<UInt16>>(inout fallbackPtr),
                CPointer<Int32>(inout errorCode),
                CPointer<CPointer<UInt16>>(inout descriptionPtr),
                CPointer<CPointer<UInt16>>(inout referencePtr)
            )
        )
    }
    if (hr.failed()) {
        return None
    }

    let fallback = BasicString.fromRaw(fallbackPtr)
    let description = BasicString.fromRaw(descriptionPtr)
    let reference = BasicString.fromRaw(referencePtr)

    try {
        let primaryText = description.toString()
        if (!primaryText.isEmpty()) {
            return Some(primaryText)
        }

        let fallbackText = fallback.toString()
        if (!fallbackText.isEmpty()) {
            return Some(fallbackText)
        }

        Some("")
    } finally {
        reference.close()
        description.close()
        fallback.close()
    }
}

func captureErrorInfoMessage(raw: CPointer<IErrorInfo>): Option<String> {
    if (raw.isNull()) {
        return None
    }

    match (comQueryInterfaceRaw<IErrorInfo, IRestrictedErrorInfo>(raw, IID_IRestrictedErrorInfo)) {
        case Some(restricted) =>
            try {
                match (captureRestrictedDescription(restricted)) {
                    case Some(text) => return Some(text)
                    case None => ()
                }
            } finally {
                comReleaseRaw(restricted)
            }
        case None => ()
    }

    captureDescription(raw)
}

@When[os == "Windows"]
func captureThreadErrorInfoPointer(): CPointer<IErrorInfo> {
    var infoPtr = CPointer<IErrorInfo>()
    let hr = HRESULT(getErrorInfoAbi(0u32, CPointer<CPointer<IErrorInfo>>(inout infoPtr)))
    if (hr.failed()) {
        return CPointer<IErrorInfo>()
    }
    infoPtr
}

@When[os == "Windows"]
struct ErrorInfo {
    private let ptr: Option<ComHandle<IErrorInfo>>

    init() {
        this.ptr = None
    }

    init(ptr: Option<ComHandle<IErrorInfo>>) {
        this.ptr = ptr
    }

    static func empty(): ErrorInfo {
        ErrorInfo()
    }

    static func fromThread(): ErrorInfo {
        let raw = captureThreadErrorInfoPointer()
        if (raw.isNull()) {
            return ErrorInfo.empty()
        }
        ErrorInfo(Some(ComHandle<IErrorInfo>.fromAbiTake(raw)))
    }

    static func fromRaw(ptr: CPointer<IErrorInfo>, addRef!: Bool = false): ErrorInfo {
        if (ptr.isNull()) {
            return ErrorInfo.empty()
        }
        ErrorInfo(Some(ComHandle<IErrorInfo>(ptr, addRef: addRef)))
    }

    func intoThread(): Unit {
        match (ptr) {
            case Some(info) =>
                if (HRESULT(setErrorInfoAbi(0u32, CPointer<Unit>(info.asRaw()))).failed()) {
                    // SetErrorInfo 失败：SetErrorInfo 未接管引用计数，需手动释放。
                    // 调用 close() 而非 comReleaseRaw，避免 GC 析构器再次 Release（double free）。
                    info.close()
                }
            case None =>
                ()
        }
    }

    func message(): Option<String> {
        match (ptr) {
            case Some(info) => captureErrorInfoMessage(info.asRaw())
            case None => None
        }
    }

    func asPtr(): CPointer<Unit> {
        match (ptr) {
            case Some(info) => CPointer<Unit>(info.asRaw())
            case None => CPointer<Unit>()
        }
    }
}

@When[os != "Windows"]
struct ErrorInfo {
    init() {}

    static func empty(): ErrorInfo {
        ErrorInfo()
    }

    static func fromThread(): ErrorInfo {
        ErrorInfo()
    }

    static func fromRaw(_: CPointer<IErrorInfo>, addRef!: Bool = false): ErrorInfo {
        ErrorInfo()
    }

    func intoThread(): Unit {}

    func message(): Option<String> {
        None
    }

    func asPtr(): CPointer<Unit> {
        CPointer<Unit>()
    }
}

@When[os == "Windows"]
func createNewError(code: HRESULT, text: String): Error {
    originateError(code, text)
    Error.fromHRESULTWithInfo(code)
}

@When[os != "Windows"]
func createNewError(code: HRESULT, _: String): Error {
    Error.fromHRESULT(code)
}

@When[os == "Windows"]
func slimErrorsEnabledForTesting(): Bool {
    false
}

@When[os != "Windows"]
func slimErrorsEnabledForTesting(): Bool {
    true
}

public struct Error <: ToString & Hashable & Comparable<Error> {
    private let hresult: HRESULT
    private let info: ErrorInfo

    public init(code: HRESULT) {
        this.hresult = code
        this.info = ErrorInfo.empty()
    }

    init(code: HRESULT, info: ErrorInfo) {
        this.hresult = code
        this.info = info
    }

    init(code: HRESULT, infoPtr: CPointer<IErrorInfo>, detailMessage: Option<String>) {
        let _ = detailMessage
        this.hresult = code
        this.info = ErrorInfo.fromRaw(infoPtr, addRef: true)
    }

    public init(code: HRESULT, message: String) {
        let created = Error.new(code, message)
        this.hresult = created.hresult
        this.info = created.info
    }

    public static func empty(): Error {
        Error(S_OK)
    }

    public static func new<T>(code: HRESULT, message: T): Error where T <: ToString {
        let text = message.toString()
        if (text.isEmpty()) {
            return Error.fromHRESULT(code)
        }
        createNewError(code, text)
    }

    public static func from(code: HRESULT): Error {
        Error.fromHRESULTWithInfo(code)
    }

    public static func from(code: WIN32_ERROR): Error {
        Error.from(code.toHRESULT())
    }

    public static func from(code: NTSTATUS): Error {
        Error.from(code.toHRESULT())
    }

    public static func from(code: RPC_STATUS): Error {
        Error.from(code.toHRESULT())
    }

    public static func fromHRESULT(code: HRESULT): Error {
        Error(code)
    }

    public static func fromHRESULTWithInfo(code: HRESULT): Error {
        Error(code, ErrorInfo.fromThread())
    }

    public static func fromWin32(code: UInt32): Error {
        Error.from(WIN32_ERROR(code))
    }

    public static func fromWin32(code: WIN32_ERROR): Error {
        Error.from(code)
    }

    public static func fromThread(): Error {
        Error.fromHRESULT(HRESULT.fromThread())
    }

    public func code(): HRESULT {
        hresult
    }

    public func asPtr(): CPointer<Unit> {
        info.asPtr()
    }

    public func intoThread(): Unit {
        info.intoThread()
    }

    public func message(): String {
        match (info.message()) {
            case Some(message) => message
            case None => hresult.message()
        }
    }

    public func hashCode(): Int64 {
        hresult.hashCode()
    }

    public func compare(other: Error): Ordering {
        hresult.compare(other.hresult)
    }

    public operator func ==(other: Error): Bool {
        hresult == other.hresult
    }

    public func toString(): String {
        let codeText = hresult.toString()
        let text = message()
        if (text.isEmpty() || text == codeText) {
            return codeText
        }
        "${text} (${codeText})"
    }
}

public func errorFromHRESULT(code: HRESULT): Error {
    Error.from(code)
}

public func errorFromHRESULTWithInfo(code: HRESULT): Error {
    Error.fromHRESULTWithInfo(code)
}

public func errorFromWin32(code: UInt32): Error {
    Error.from(WIN32_ERROR(code))
}

public func errorFromThread(): Error {
    Error.fromThread()
}

func errorFromRawForTesting(code: HRESULT, infoPtr: CPointer<IErrorInfo>): Error {
    Error(code, infoPtr, None)
}

func errorNewForTesting<T>(code: HRESULT, message: T): Error where T <: ToString {
    Error.new(code, message)
}

public func errorCode(error: Error): HRESULT {
    error.code()
}

public func errorToHRESULT(error: Error): HRESULT {
    error.intoThread()
    error.code()
}

public open class WindowsException <: Exception {
    let error: Error
    let hr: HRESULT

    public init(error: Error) {
        super(error.toString())
        this.error = error
        this.hr = errorCode(error)
    }

    public init(hr: HRESULT) {
        super(Error.fromHRESULT(hr).toString())
        this.error = Error.fromHRESULT(hr)
        this.hr = hr
    }
}

class ComException <: WindowsException {
    public init(error: Error) {
        super(error)
    }

    public init(hr: HRESULT) {
        super(hr)
    }
}

public class Win32Exception <: WindowsException {
    let errorCode: UInt32

    public init(errorCode: UInt32) {
        super(Error.fromWin32(errorCode))
        this.errorCode = errorCode
    }

    public init(errorCode: WIN32_ERROR) {
        super(Error.fromWin32(errorCode))
        this.errorCode = errorCode.value
    }
}
