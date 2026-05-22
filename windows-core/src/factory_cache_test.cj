package windows_core

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*

let factoryCacheTestLoadCalls = AtomicInt64(0)
let factoryCacheTestIncrementCalls = AtomicInt64(0)
let factoryCacheTestRegFreeCalls = AtomicInt64(0)

func resetFactoryCacheTestActivationHooks() {
    factoryCacheTestLoadCalls.store(0)
    factoryCacheTestIncrementCalls.store(0)
    factoryCacheTestRegFreeCalls.store(0)
}

func factoryCacheTestNotInitializedLoader(
    _: HString,
    _: CPointer<GUID>,
    _: CPointer<CPointer<Unit>>
): HRESULT {
    factoryCacheTestLoadCalls.fetchAdd(1)
    CO_E_NOTINITIALIZED
}

func factoryCacheTestFailingMTAIncrement(_: CPointer<CPointer<Unit>>): HRESULT {
    factoryCacheTestIncrementCalls.fetchAdd(1)
    E_ACCESSDENIED
}

func factoryCacheTestFakeMTAUsageCookie(): CPointer<Unit> {
    unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x4321) }
}

func factoryCacheTestSuccessfulMTAIncrement(cookie: CPointer<CPointer<Unit>>): HRESULT {
    factoryCacheTestIncrementCalls.fetchAdd(1)
    unsafe { cookie.write(factoryCacheTestFakeMTAUsageCookie()) }
    S_OK
}

func factoryCacheTestNotInitializedThenFailureLoader(
    _: HString,
    _: CPointer<GUID>,
    _: CPointer<CPointer<Unit>>
): HRESULT {
    let previous = factoryCacheTestLoadCalls.fetchAdd(1)
    if (previous % 2 == 0) {
        return CO_E_NOTINITIALIZED
    }
    E_FAIL
}

func factoryCacheTestMissingThenLoadedFailure(
    _: String,
    _: Array<UInt8>,
    _: InterfaceDescriptor<IUnknown>
): RegFreeFactoryLoad<IUnknown> {
    let previous = factoryCacheTestRegFreeCalls.fetchAdd(1)
    if (previous == 0) {
        return RegFreeFactoryLoad<IUnknown>.MissingCandidate
    }
    if (previous == 1) {
        return RegFreeFactoryLoad<IUnknown>.Loaded(Result<IUnknown>.Err(WinError.fromHRESULT(E_FAIL)))
    }
    RegFreeFactoryLoad<IUnknown>.Loaded(Result<IUnknown>.Err(WinError.fromHRESULT(E_POINTER)))
}

@Test
func testLoadFactoryByNameReturnsResultForMissingClass() {
    let result = loadFactoryByName("Windows.Cangjie.MissingActivationClass", IUnknown.descriptor())

    @Expect(result.isErr(), true)
}

@Test
func testSystemActivationFactoryPreservesMTAIncrementFailure() {
    resetFactoryCacheTestActivationHooks()
    let result = loadSystemActivationFactoryWithCalls<IUnknown>(
        "Windows.Cangjie.MissingActivationClass",
        IUnknown.descriptor(),
        factoryCacheTestNotInitializedLoader,
        factoryCacheTestFailingMTAIncrement,
        mtaUsage: FactoryMTAUsageGuard()
    )

    match (result) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
            throw Exception("loadSystemActivationFactoryWithCalls unexpectedly succeeded")
        case Result<IUnknown>.Err(error) =>
            @Expect(error.code(), E_ACCESSDENIED)
    }
    @Expect(factoryCacheTestLoadCalls.load(), 1)
    @Expect(factoryCacheTestIncrementCalls.load(), 1)
}

@Test
func testSystemActivationFactoryUsesSingleProcessMTAUsageGuard() {
    resetFactoryCacheTestActivationHooks()
    let mtaUsage = FactoryMTAUsageGuard()
    let first = loadSystemActivationFactoryWithCalls<IUnknown>(
        "Windows.Cangjie.MissingActivationClass",
        IUnknown.descriptor(),
        factoryCacheTestNotInitializedThenFailureLoader,
        factoryCacheTestSuccessfulMTAIncrement,
        mtaUsage: mtaUsage
    )
    let second = loadSystemActivationFactoryWithCalls<IUnknown>(
        "Windows.Cangjie.MissingActivationClass",
        IUnknown.descriptor(),
        factoryCacheTestNotInitializedThenFailureLoader,
        factoryCacheTestSuccessfulMTAIncrement,
        mtaUsage: mtaUsage
    )

    match (first) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
            throw Exception("loadSystemActivationFactoryWithCalls unexpectedly succeeded")
        case Result<IUnknown>.Err(error) =>
            @Expect(error.code(), E_FAIL)
    }
    match (second) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
            throw Exception("loadSystemActivationFactoryWithCalls unexpectedly succeeded")
        case Result<IUnknown>.Err(error) =>
            @Expect(error.code(), E_FAIL)
    }
    @Expect(factoryCacheTestLoadCalls.load(), 4)
    @Expect(factoryCacheTestIncrementCalls.load(), 1)
}

@Test
func testRegFreeActivationPreservesLoadedCandidateFailure() {
    resetFactoryCacheTestActivationHooks()
    let result = loadRegFreeActivationFactoryWithLoader<IUnknown>(
        "Windows.Cangjie.MissingActivationClass",
        IUnknown.descriptor(),
        factoryCacheTestMissingThenLoadedFailure
    )

    match (result) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
            throw Exception("loadRegFreeActivationFactoryWithLoader unexpectedly succeeded")
        case Result<IUnknown>.Err(error) =>
            @Expect(error.code(), E_FAIL)
    }
    @Expect(factoryCacheTestRegFreeCalls.load(), 2)
}
