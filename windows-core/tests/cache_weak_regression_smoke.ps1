$ErrorActionPreference = "Stop"

$repoRoot = "E:/Project/CS_Project/2026/ling"
$packageRoot = Join-Path $repoRoot "windows-cj/windows-core"
$workspaceRoot = Join-Path $packageRoot "tests/output/cache_weak_regression_smoke"
$runnerRoot = Join-Path $workspaceRoot "runner"
$srcRoot = Join-Path $runnerRoot "src"

if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $srcRoot | Out-Null

$manifest = @'
[package]
  name = "windows_core_cache_weak_regression_smoke"
  version = "0.1.0"
  description = "Regression smoke test for windows_core weak marshaler and factory cache bugs"
  output-type = "executable"
  cjc-version = "1.1.0"
  compile-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_core = { path = "E:/Project/CS_Project/2026/ling/windows-cj/windows-core" }
  windows_implement = { path = "E:/Project/CS_Project/2026/ling/windows-cj/windows-implement" }
'@

$main = @'
package windows_core_cache_weak_regression_smoke

import std.sync.*
import windows_core.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

public class DemoInner {
    public let id: Int32

    public init(id: Int32) {
        this.id = id
    }
}

public class DemoRuntimeName <: RuntimeName {
    public init() {}

    public static func runtimeName(): String {
        "Demo.Runtime.Type"
    }
}

func fail(msg: String): Nothing {
    throw SmokeFailure(msg)
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

func spinUntil(predicate: () -> Bool, timeoutMessage: String): Unit {
    var attempts = 0
    while (!predicate()) {
        if (attempts >= 5000) {
            fail(timeoutMessage)
        }
        sleep(Duration.millisecond)
        attempts += 1
    }
}

func requireFactoryRaw(
    label: String,
    value: Result<IUnknown>
): UIntNative {
    match (value) {
        case Result<IUnknown>.Ok(factory) =>
            try {
                let raw = factory.asRaw()
                if (raw.isNull()) {
                    fail("${label}: factory wrapper should stay live")
                }
                raw.toUIntNative()
            } finally {
                factory.close()
            }
        case Result<IUnknown>.Err(error) =>
            fail("${label}: ${error}")
    }
}

func expectObjectMarshalerRoundTrip(
    owner: IUnknown,
    expectedObjectRaw: CPointer<Unit>,
    attempt: Int64
): Unit {
    match (unsafe { owner.query(IMarshal.descriptor()) }) {
        case Some(marshaler) =>
            try {
                if (marshaler.asRaw().isNull()) {
                    fail("object marshaler attempt ${attempt} returned a null raw pointer")
                }
                match (unsafe { marshaler.query(IInspectable.descriptor()) }) {
                    case Some(inspectable) =>
                        if (!samePointer(inspectable.asRaw(), expectedObjectRaw)) {
                            fail("object marshaler attempt ${attempt} should aggregate back to the outer object")
                        }
                        inspectable.close()
                    case None =>
                        fail("object marshaler attempt ${attempt} should still forward QueryInterface to the outer object")
                }
            } finally {
                marshaler.close()
            }
        case None =>
            fail("object marshaler attempt ${attempt} should succeed")
    }
}

func expectWeakMarshalerRoundTrip(
    reference: IWeakReference,
    expectedWeakRaw: CPointer<Unit>,
    attempt: Int64
): Unit {
    match (unsafe { reference.query(IMarshal.descriptor()) }) {
        case Some(marshaler) =>
            try {
                if (marshaler.asRaw().isNull()) {
                    fail("weak marshaler attempt ${attempt} returned a null raw pointer")
                }
                match (unsafe { marshaler.query(IWeakReference.descriptor()) }) {
                    case Some(rebound) =>
                        if (!samePointer(rebound.asRaw(), expectedWeakRaw)) {
                            fail("weak marshaler attempt ${attempt} should aggregate back to the weak reference identity")
                        }
                        rebound.close()
                    case None =>
                        fail("weak marshaler attempt ${attempt} should still forward QueryInterface to the weak reference identity")
                }
            } finally {
                marshaler.close()
            }
        case None =>
            fail("weak marshaler attempt ${attempt} should succeed")
    }
}

func expectWeakMarshalerCache(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let object = createComObjectFromSchemas(DemoInner(1i32), schemas)
    let unknown = object.toInterface(IUnknown.descriptor())

    for (attempt in 1..128) {
        expectObjectMarshalerRoundTrip(unknown, object.asRaw(), attempt)
        let throwaway = createComObjectFromSchemas(DemoInner(Int32(attempt) + 1000i32), schemas)
        let throwawayFinalCount = IUnknown(throwaway.asRaw()).release()
        if (throwawayFinalCount != 0u32) {
            fail("throwaway object marshaler probe ${attempt} should release cleanly")
        }
    }

    match (unsafe { queryInterfaceAs(unknown.asRaw(), IWeakReferenceSource.descriptor()) }) {
        case Some(source) =>
            try {
                match (unsafe { source.getWeakReference() }) {
                    case Result<IWeakReference>.Ok(reference) =>
                        try {
                            for (attempt in 1..128) {
                                expectWeakMarshalerRoundTrip(reference, reference.asRaw(), attempt)
                                let throwaway = createComObjectFromSchemas(DemoInner(Int32(attempt) + 2000i32), schemas)
                                let throwawayFinalCount = IUnknown(throwaway.asRaw()).release()
                                if (throwawayFinalCount != 0u32) {
                                    fail("throwaway weak marshaler probe ${attempt} should release cleanly")
                                }
                            }
                        } finally {
                            reference.close()
                        }
                    case Result<IWeakReference>.Err(error) =>
                        fail("getWeakReference should succeed for local agile objects: ${error}")
                }
            } finally {
                source.close()
            }
        case None =>
            fail("local agile objects should expose IWeakReferenceSource")
    }

    unknown.close()
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("weak marshaler probe object should release cleanly")
    }
}

func expectFactoryCacheFirstWriterWins(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let firstObject = createComObjectFromSchemas(DemoInner(1i32), schemas)
    let secondObject = createComObjectFromSchemas(DemoInner(2i32), schemas)
    let cache = FactoryCache<DemoRuntimeName, IUnknown>.new(IUnknown.descriptor())
    let started = AtomicInt64(0)
    let releaseFirst = AtomicInt64(0)
    let releaseSecond = AtomicInt64(0)

    let firstFuture = spawn {
        requireFactoryRaw(
            "first concurrent load",
            cache.factory({ =>
                started.fetchAdd(1)
                spinUntil({ => started.load() == 2 }, "both concurrent loaders should start before the first returns")
                spinUntil({ => releaseFirst.load() == 1 }, "first concurrent loader was never released")
                Result<IUnknown>.Ok(firstObject.toInterface(IUnknown.descriptor()))
            })
        )
    }

    let secondFuture = spawn {
        requireFactoryRaw(
            "second concurrent load",
            cache.factory({ =>
                started.fetchAdd(1)
                spinUntil({ => started.load() == 2 }, "both concurrent loaders should start before the second returns")
                spinUntil({ => releaseSecond.load() == 1 }, "second concurrent loader was never released")
                Result<IUnknown>.Ok(secondObject.toInterface(IUnknown.descriptor()))
            })
        )
    }

    spinUntil({ => started.load() == 2 }, "both factory loaders should reach the synchronization gate")
    releaseFirst.store(1)
    let firstRaw = firstFuture.get()
    if (firstRaw != firstObject.asRaw().toUIntNative()) {
        fail("the first concurrent caller should resolve the first loader result")
    }

    releaseSecond.store(1)
    let secondRaw = secondFuture.get()
    if (secondRaw != firstRaw) {
        fail("concurrent cache writes should preserve the first cached factory instead of letting the last writer win")
    }

    let cachedRaw = requireFactoryRaw(
        "cached follow-up load",
        cache.factory({ =>
            fail("the cached follow-up path should not invoke the loader again")
        })
    )
    if (cachedRaw != firstRaw) {
        fail("cached follow-up loads should keep returning the first cached factory")
    }

    cache.close()
    let firstFinalCount = IUnknown(firstObject.asRaw()).release()
    if (firstFinalCount != 0u32) {
        fail("first cached factory probe object should release cleanly")
    }
    let secondFinalCount = IUnknown(secondObject.asRaw()).release()
    if (secondFinalCount != 0u32) {
        fail("second cached factory probe object should release cleanly")
    }
}

func expectFactoryCacheCloseRejectsInFlightLoad(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let object = createComObjectFromSchemas(DemoInner(3i32), schemas)
    let cache = FactoryCache<DemoRuntimeName, IUnknown>.new(IUnknown.descriptor())
    let loaderStarted = AtomicInt64(0)
    let releaseLoader = AtomicInt64(0)

    let inFlightLoad = spawn {
        cache.factory({ =>
            loaderStarted.store(1)
            spinUntil({ => releaseLoader.load() == 1 }, "FactoryCache.close should release the blocked loader")
            Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
        })
    }

    spinUntil({ => loaderStarted.load() == 1 }, "FactoryCache loader should reach the synchronization gate")
    cache.close()
    releaseLoader.store(1)

    match (inFlightLoad.get()) {
        case Result<IUnknown>.Ok(factory) =>
            try {
                fail("FactoryCache.factory should fail if close wins before the new cached pointer is stored")
            } finally {
                factory.close()
            }
        case Result<IUnknown>.Err(error) =>
            if (error.code() != E_POINTER) {
                fail("FactoryCache.factory should report E_POINTER after close, got ${error}")
            }
    }

    match (cache.factory({ =>
        fail("closed FactoryCache should not invoke follow-up loaders")
    })) {
        case Result<IUnknown>.Ok(factory) =>
            try {
                fail("closed FactoryCache should reject follow-up factory calls")
            } finally {
                factory.close()
            }
        case Result<IUnknown>.Err(error) =>
            if (error.code() != E_POINTER) {
                fail("closed FactoryCache follow-up calls should report E_POINTER, got ${error}")
            }
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("FactoryCache close-race probe object should release cleanly")
    }
}

func expectEventCloseRejectsConcurrentAdd(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })

    for (attempt in 1..4) {
        let object = createComObjectFromSchemas(DemoInner(Int32(attempt) + 10i32), schemas)
        let unknown = object.toInterface(IUnknown.descriptor())
        let event = Event<IUnknown>.new(IUnknown.descriptor())

        for (_ in 1..2048) {
            event.add(unknown).expect("Event.add should accept seed delegates before the close race probe")
        }

        let closeStarted = AtomicInt64(0)
        let closeFinished = AtomicInt64(0)
        let closeFuture = spawn {
            closeStarted.store(1)
            event.close()
            closeFinished.store(1)
        }

        spinUntil({ => closeStarted.load() == 1 }, "Event.close should start before probing concurrent add")
        sleep(Duration.millisecond)

        var lateToken: Option<EventToken> = None
        while (closeFinished.load() == 0) {
            match (event.add(unknown)) {
                case Result<EventToken>.Ok(token) =>
                    lateToken = Some(token)
                    break
                case Result<EventToken>.Err(_) =>
                    sleep(Duration.millisecond)
            }
        }
        closeFuture.get()

        match (lateToken) {
            case Some(token) =>
                fail("Event.add should not succeed after Event.close starts clearing handlers; leaked token ${token.value} on attempt ${attempt}")
            case None =>
                ()
        }

        let postCloseCallCount = AtomicInt64(0)
        event.call({ _: IUnknown =>
            postCloseCallCount.fetchAdd(1)
            Result<Unit>.Ok(())
        })
        if (postCloseCallCount.load() != 0) {
            fail("Event.close should leave no handlers callable after the close/add race probe")
        }

        unknown.close()
        let finalCount = IUnknown(object.asRaw()).release()
        if (finalCount != 0u32) {
            fail("Event close-race probe object should release cleanly on attempt ${attempt}")
        }
    }
}

main(_: Array<String>) {
    expectWeakMarshalerCache()
    expectFactoryCacheFirstWriterWins()
    expectFactoryCacheCloseRejectsInFlightLoad()
    expectEventCloseRejectsConcurrentAdd()
}
'@

Set-Content -Path (Join-Path $runnerRoot "cjpm.toml") -Value $manifest -NoNewline
Set-Content -Path (Join-Path $srcRoot "main.cj") -Value $main -NoNewline

Push-Location $runnerRoot
try {
    cjpm build | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm build failed"
    }
    $runOutput = cjpm run 2>&1 | Tee-Object -Variable regressionSmokeOutput | Out-String
    $regressionSmokeOutput | Out-Host
    if ($LASTEXITCODE -ne 0 -or $runOutput -match "An exception has occurred") {
        throw "cjpm run failed"
    }
}
finally {
    Pop-Location
}

Write-Host "windows-core cache/weak regression smoke test passed."
