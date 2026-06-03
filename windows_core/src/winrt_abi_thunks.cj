package windows_core

// Shared WinRT-ABI thunk / out-slot helpers. Previously internal to the
// foundation projection package; down-sinked to windows_core so that the
// foundation and future async projection packages can both consume them
// without forming a dependency cycle. These helpers are pure ABI plumbing
// and reference only windows_core / windows_strings symbols.

public func checkFoundationComOutHRESULT(hr: HRESULT, result: CPointer<CPointer<Unit>>): Unit {
    if (hr.failed()) {
        releaseFailedComOutSlot(result)
    }
    hr.check()
}

public func checkFoundationHStringOutHRESULT(hr: HRESULT, result: CPointer<CPointer<Unit>>): Unit {
    if (hr.failed()) {
        cleanupFoundationHStringOutSlot(result)
    }
    hr.check()
}

public func cleanupFoundationHStringOutSlot(result: CPointer<CPointer<Unit>>): Unit {
    if (result.isNotNull()) {
        let raw = unsafe { result.read() }
        if (raw.isNotNull()) {
            releaseSystemHStringHandle(raw)
            unsafe { result.write(CPointer<Unit>()) }
        }
    }
}

public func clearFoundationComOutSlot(result: CPointer<CPointer<Unit>>): Unit {
    unsafe { result.write(CPointer<Unit>()) }
}

public func foundationNotImplValueOut<T>(result: CPointer<T>, value: T): Int32 where T <: CType {
    if (result.isNotNull()) {
        unsafe { result.write(value) }
    }
    E_NOTIMPL.value
}

public func foundationNotImplArrayOut<T>(valueSize: CPointer<UInt32>, value: CPointer<CPointer<T>>): Int32 where T <: CType {
    clearFoundationArrayOut<T>(valueSize, value)
    E_NOTIMPL.value
}

public func foundationNotImplUnitArrayOut(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Unit>>): Int32 {
    clearFoundationUnitArrayOut(valueSize, value)
    E_NOTIMPL.value
}

public func foundationNotImplComOut(result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNotNull()) {
        clearFoundationComOutSlot(result)
    }
    E_NOTIMPL.value
}

public func foundationNoInterfaceValueOut<T>(result: CPointer<T>, value: T): Int32 where T <: CType {
    if (result.isNotNull()) {
        unsafe { result.write(value) }
    }
    E_NOINTERFACE.value
}

public func clearFoundationArrayOut<T>(valueSize: CPointer<UInt32>, value: CPointer<CPointer<T>>): Unit where T <: CType {
    if (valueSize.isNotNull()) {
        unsafe { valueSize.write(0u32) }
    }
    if (value.isNotNull()) {
        unsafe { value.write(CPointer<T>()) }
    }
}

public func clearFoundationUnitArrayOut(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Unit>>): Unit {
    if (valueSize.isNotNull()) {
        unsafe { valueSize.write(0u32) }
    }
    if (value.isNotNull()) {
        unsafe { value.write(CPointer<Unit>()) }
    }
}

public func foundationNoInterfaceArrayOut<T>(valueSize: CPointer<UInt32>, value: CPointer<CPointer<T>>): Int32 where T <: CType {
    clearFoundationArrayOut<T>(valueSize, value)
    E_NOINTERFACE.value
}

public func foundationNoInterfaceUnitArrayOut(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Unit>>): Int32 {
    clearFoundationUnitArrayOut(valueSize, value)
    E_NOINTERFACE.value
}

public func foundationNoInterfaceComOut(result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNotNull()) {
        clearFoundationComOutSlot(result)
    }
    E_NOINTERFACE.value
}

public func foundationNoInterfaceUInt32Out(result: CPointer<UInt32>): Int32 {
    if (result.isNotNull()) {
        unsafe { result.write(0u32) }
    }
    E_NOINTERFACE.value
}

public func foundationNoInterfaceBoolOut(result: CPointer<Bool>): Int32 {
    if (result.isNotNull()) {
        unsafe { result.write(false) }
    }
    E_NOINTERFACE.value
}

public func foundationDirectScalarOutThunk<T>(
    result: CPointer<T>,
    defaultValue: T,
    action: () -> Result<T>
): Int32 where T <: CType {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(defaultValue) }
    try {
        match (action()) {
            case Result<T>.Ok(value) =>
                unsafe { result.write(value) }
                S_OK.value
            case Result<T>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        error.code().value
    } catch (_: Exception) {
        E_FAIL.value
    }
}

public func foundationProjectedScalarOutThunk<TProjected, TAbi, TDefault>(
    result: CPointer<TAbi>,
    defaultValue: TAbi,
    action: () -> Result<TProjected>
): Int32 where TProjected <: Type<TProjected, TAbi, TDefault>, TAbi <: CType {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(defaultValue) }
    try {
        match (action()) {
            case Result<TProjected>.Ok(value) =>
                unsafe { result.write(projectTypedAbi(value, typeMarker<TProjected>())) }
                S_OK.value
            case Result<TProjected>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        error.code().value
    } catch (_: Exception) {
        E_FAIL.value
    }
}

public func foundationUnitThunk(action: () -> Result<Unit>): Int32 {
    try {
        match (action()) {
            case Result<Unit>.Ok(_) =>
                S_OK.value
            case Result<Unit>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        error.code().value
    } catch (_: Exception) {
        E_FAIL.value
    }
}

public func foundationHStringOutThunk(
    result: CPointer<CPointer<Unit>>,
    action: () -> Result<HString>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    try {
        match (action()) {
            case Result<HString>.Ok(value) =>
                winrtStoreGenericOut<HString>(result, value)
            case Result<HString>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        cleanupFoundationHStringOutSlot(result)
        error.code().value
    } catch (_: Exception) {
        cleanupFoundationHStringOutSlot(result)
        E_FAIL.value
    }
}

public func cleanupFoundationGenericOutSlot<T>(result: CPointer<CPointer<Unit>>): Unit where T <: WinrtGenericType<T> {
    if (result.isNull()) {
        return
    }
    winrtReleaseGenericOutRangeNoThrow<T>(CPointer<Unit>(result), 1u32)
}

public func winrtReleaseGenericOutRangeNoThrow<T>(
    buffer: CPointer<Unit>,
    length: UInt32
): Unit where T <: WinrtGenericType<T> {
    try {
        winrtReleaseGenericOutRange<T>(buffer, length)
    } catch (_: Exception) {
        ()
    }
}

public func foundationGenericOutThunk<T>(
    result: CPointer<CPointer<Unit>>,
    action: () -> Result<T>
): Int32 where T <: WinrtGenericType<T> {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    try {
        match (action()) {
            case Result<T>.Ok(value) =>
                let hr = winrtStoreGenericOut<T>(result, value)
                if (HRESULT(hr).failed()) {
                    cleanupFoundationGenericOutSlot<T>(result)
                }
                hr
            case Result<T>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        cleanupFoundationGenericOutSlot<T>(result)
        error.code().value
    } catch (_: Exception) {
        cleanupFoundationGenericOutSlot<T>(result)
        E_FAIL.value
    }
}

public func foundationReferenceArrayValueThunk(
    resultSize: CPointer<UInt32>,
    result: CPointer<CPointer<Unit>>,
    action: () -> Result<(UInt32, CPointer<Unit>)>
): Int32 {
    if (resultSize.isNull() || result.isNull()) {
        clearFoundationUnitArrayOut(resultSize, result)
        return E_POINTER.value
    }
    unsafe {
        resultSize.write(0u32)
        result.write(CPointer<Unit>())
    }
    try {
        match (action()) {
            case Result<(UInt32, CPointer<Unit>)>.Ok(value) =>
                let (size, data) = value
                unsafe { resultSize.write(size) }
                unsafe { result.write(CPointer<Unit>(data)) }
                S_OK.value
            case Result<(UInt32, CPointer<Unit>)>.Err(error) =>
                error.code().value
        }
    } catch (error: WindowsException) {
        error.code().value
    } catch (_: Exception) {
        E_FAIL.value
    }
}

public func foundationPropertyValueArrayOutThunk(
    prepareResult: Int32,
    action: () -> Result<Unit>,
    cleanup: () -> Unit
): Int32 {
    if (prepareResult != S_OK.value) {
        return prepareResult
    }
    try {
        match (action()) {
            case Result<Unit>.Ok(_) =>
                S_OK.value
            case Result<Unit>.Err(error) =>
                cleanup()
                error.code().value
        }
    } catch (error: WindowsException) {
        cleanup()
        error.code().value
    } catch (_: Exception) {
        cleanup()
        E_FAIL.value
    }
}
