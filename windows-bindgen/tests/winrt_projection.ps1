$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureWinmd = Join-Path $repoRoot "windows-cj/winmd/Windows.winmd"
$outputRoot = Join-Path $packageRoot "tests/output/winrt_projection"

if (!(Test-Path $fixtureWinmd)) {
    throw "Missing fixture winmd: $fixtureWinmd"
}

Push-Location $packageRoot
try {
    cjpm build | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $outputRoot `
        --flat `
        --no-sys `
        --high-level `
        --filter Windows.Foundation | Out-Host
}
finally {
    Pop-Location
}

$foundationFile = Join-Path $outputRoot "Foundation.cj"
if (!(Test-Path $foundationFile)) {
    throw "Missing generated WinRT foundation source: $foundationFile"
}

$foundation = Get-Content -Raw $foundationFile

if ($foundation -notmatch 'public class Uri\b') {
    throw "High-level WinRT projection did not generate runtime class wrappers"
}
if ($foundation -notmatch 'public class AsyncActionCompletedHandler\b') {
    throw "WinRT delegates are still emitted as raw function aliases"
}
if ($foundation -match 'public type AsyncActionCompletedHandler = CFunc') {
    throw "WinRT delegates should not be emitted as CFunc aliases"
}
if ($foundation -notmatch 'public static func runtimeType\(\): RuntimeTypeContract') {
    throw "WinRT projection is missing RuntimeType metadata"
}
if ($foundation -notmatch 'RuntimeTypeContract\("Windows\.Foundation\.Uri"') {
    throw "RuntimeType metadata is missing runtime class names"
}
if ($foundation -notmatch 'public static func activationFactory\(\): Option<IActivationFactory>') {
    throw "WinRT runtime classes are missing IActivationFactory helpers"
}
if ($foundation -notmatch 'windows_interface\.getActivationFactoryByName<IActivationFactory>\(Uri\.runtimeName\(\), IActivationFactory\.descriptor\(\)\)\.ok\(\)') {
    throw "WinRT runtime classes are not using runtime-name based activation factory resolution"
}
if ($foundation -notmatch 'public static func isAgile\(\): Bool') {
    throw "WinRT runtime classes are missing agile metadata helpers"
}
if ($foundation -notmatch 'public static unsafe func CreateUri\(uri: CPointer<UInt16>\): Uri') {
    throw "WinRT class factory methods from StaticAttribute or ActivatableAttribute were not generated"
}
if ($foundation -notmatch 'getActivationFactoryByName<IUriRuntimeClassFactory>\(Uri\.runtimeName\(\), IUriRuntimeClassFactory\.descriptor\(\)\)\.unwrap\(\)') {
    throw "WinRT class factory methods are not connected through activation factory lookup"
}
if ($foundation -notmatch 'public var base_: IInspectableVtbl = IInspectableVtbl\(\)') {
    throw "WinRT interfaces should inherit from IInspectableVtbl"
}
if ($foundation -notmatch 'public class IReference\b') {
    throw "Generic WinRT interfaces are missing from the projection"
}
if ($foundation -notmatch 'pinterface\(\{') {
    throw "Generic WinRT interfaces are missing parameterized runtime signatures"
}
if ($foundation -notmatch 'InterfaceDescriptorSchema\("IAsyncAction", IAsyncAction\.iid\(\), IAsyncInfo\.descriptorSchema\(\)') {
    throw "WinRT interface schemas are missing direct-base schema metadata"
}
if ($foundation -notmatch 'InterfaceMethodSchema\("GetResults", 13, \[\], "Int32"\)') {
    throw "WinRT interface schemas are missing absolute abiSlot metadata"
}
if ($foundation -notmatch 'InterfaceParameterSchema\("result", "CPointer<CPointer<Unit>>", "OutSlot<Uri>", InterfaceParameterBridgeKind\.OutSlot\)') {
    throw "WinRT interface schemas are missing caller-side OutSlot parameter metadata"
}
if ($foundation -notmatch 'public static func fromAbiTake\(raw: CPointer<Unit>\): IAsyncAction') {
    throw "WinRT interface wrappers are missing ABI-take constructors"
}
$legacyRawViewName = 'fromRaw' + 'Borrowed'
if ($foundation -match $legacyRawViewName) {
    throw "High-level WinRT projection should not emit call-view raw constructor aliases"
}
if ($foundation -match 'OutRef<') {
    throw "High-level WinRT projection should not expose OutRef caller-side metadata"
}
if ($foundation -match 'Ref<') {
    throw "High-level WinRT projection should not expose Ref caller-side metadata"
}
if ($foundation -notmatch 'descriptor\.runtimeTypeContract = Some\(IUriRuntimeClass\.runtimeType\(\)\)') {
    throw "WinRT descriptors are missing runtime-type metadata wiring"
}
if ($foundation -notmatch 'public static func runtimeName\(\): String') {
    throw "WinRT interface wrappers are missing RuntimeName helpers"
}
if ($foundation -notmatch 'public static func new\(invoke: \(InParam<IAsyncAction>, AsyncStatus\) -> Unit\): AsyncActionCompletedHandler') {
    throw "WinRT delegates are missing call-bound callback signatures"
}
if ($foundation -notmatch 'private open class AsyncActionCompletedHandlerInvoker') {
    throw "WinRT delegates are missing invoker support types"
}
if ($foundation -notmatch 'public override func Invoke\(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus\): Unit') {
    throw "WinRT delegate box overrides are not using call-bound callback parameters"
}
if ($foundation -notmatch 'ComObject<AsyncActionCompletedHandlerBox>\.new\(box, \[AsyncActionCompletedHandler\.descriptorSchema\(\)\], \[box\.vtblPtr\(\)\]\)') {
    throw "WinRT delegates are not boxed through ComObject"
}
if ($foundation -notmatch 'asImplFromRaw<AsyncActionCompletedHandlerInvoker>') {
    throw "WinRT delegates are missing thunk unboxing support"
}
if ($foundation -match 'windows_implement') {
    throw "High-level WinRT projection should not depend directly on windows_implement"
}

Write-Host "windows-bindgen WinRT projection smoke test passed."
