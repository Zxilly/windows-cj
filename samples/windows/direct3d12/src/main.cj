package windows_sample_direct3d12

import windows_sample_direct3d12_bindings.Win32.Graphics.Direct3D12.{
    Apis as D3D12Apis,
    ID3D12DeviceVtbl,
    ID3D12CommandQueueVtbl,
    ID3D12GraphicsCommandListVtbl,
    ID3D12DescriptorHeapVtbl,
    ID3D12ResourceVtbl,
    ID3D12FenceVtbl,
    ID3D12CommandAllocatorVtbl,
    D3D12_COMMAND_QUEUE_DESC,
    D3D12_DESCRIPTOR_HEAP_DESC,
    D3D12_CPU_DESCRIPTOR_HANDLE,
    D3D12_VIEWPORT,
    D3D12_ROOT_SIGNATURE_DESC,
    D3D12_INPUT_ELEMENT_DESC,
    D3D12_GRAPHICS_PIPELINE_STATE_DESC,
    D3D12_RENDER_TARGET_BLEND_DESC,
    D3D12_HEAP_PROPERTIES,
    D3D12_RESOURCE_DESC,
    D3D12_VERTEX_BUFFER_VIEW,
    D3D12_RESOURCE_BARRIER,
    D3D12_RESOURCE_TRANSITION_BARRIER
}
import windows_sample_direct3d12_bindings.Win32.Graphics.Direct3D.Fxc.Apis as FxcApis
import windows_sample_direct3d12_bindings.Win32.Graphics.Direct3D.ID3DBlobVtbl
import windows_sample_direct3d12_bindings.Win32.Graphics.Dxgi.{
    Apis as DxgiApis,
    IDXGIFactory4Vtbl,
    IDXGIAdapter1Vtbl,
    IDXGISwapChain3Vtbl,
    IDXGISwapChainVtbl,
    DXGI_SWAP_CHAIN_DESC1,
    DXGI_ADAPTER_DESC1
}
import windows_sample_direct3d12_bindings.Win32.System.Threading.Apis as ThreadingApis
import windows_sample_direct3d12_bindings.Win32.System.LibraryLoader.Apis as LoaderApis
import windows_sample_direct3d12_bindings.Win32.Foundation.{HWND, HINSTANCE, HANDLE, RECT}
import windows_sample_direct3d12_bindings.Win32.UI.WindowsAndMessaging.{Apis as WndApis, WNDCLASSEXA, MSG, HMENU}

import windows_core.{HRESULT, GUID, WindowsException, E_NOINTERFACE, queryInterfaceRaw, IUnknownVtbl}
import windows_strings.{narrowStringFactory, wideStringFactory}
import windows_polyfill.handlePointerFromInt

import std.fs.exists
import std.env.getCommandLine

// ============================================================================
// direct3d12 — behaviour-equivalent port of the reference sample.
//
// A Direct3D 12 "hello triangle": it enumerates DXGI adapters, creates a D3D12
// device + direct command queue, a flip-discard swap chain, an RTV descriptor
// heap and per-frame render targets, an empty root signature, runtime-compiles
// the HLSL vertex/pixel shaders with D3DCompileFromFile, builds a graphics PSO
// and an upload-heap vertex buffer, records a command list every frame and
// synchronises with a fence + event. A classic PeekMessage pump drives it.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference abstracts the sample behind a DXSample trait and a generic
//     wndproc that recovers `self` from GWLP_USERDATA. Cangjie is GC managed —
//     a managed object cannot round-trip through a raw integer, and trait
//     dispatch is unnecessary for one concrete sample. We write one concrete
//     HelloTriangle class holding every resource and publish the single window
//     in a top-level global `gSample`; the top-level @C wndproc reads it. This
//     is behaviourally identical to the reference's single-window self pointer,
//     so SetWindowLongPtrA/GWLP_USERDATA is omitted.
//   • COM interface methods are invoked through the generator's @C vtbl structs:
//     read the vtbl pointer out of the raw COM pointer and call the function
//     pointer — the exact ABI the reference's projected methods perform.
//     Inherited methods are reached through nested `base_` fields (e.g. the swap
//     chain's Present/GetBuffer live on IDXGISwapChain == three base_ hops below
//     IDXGISwapChain3, and the factory's CreateSwapChainForHwnd lives on
//     IDXGIFactory2 == two base_ hops below IDXGIFactory4).
//   • There is no `cast::<T>()`; QueryInterface is performed with the documented
//     IID via windows_core.queryInterfaceRaw, returning the AddRef'd interface
//     pointer (released when we are done with transient casts).
//   • There are no compile-time GUID literals; well-known IIDs are parsed at run
//     time from their canonical string form — the run-time analogue.
//   • Scalar D3D12/DXGI/Win32 flag values are not re-exported by the facade (only
//     the wrapped newtypes are), so the documented integer values are recorded
//     as constants below — semantically identical to the reference's enums.
//   • cfg!(debug_assertions) selects the release branch (no D3D12 debug layer,
//     no DXGI debug factory), which is behaviourally equivalent for this sample.
//   • `array_init::try_array_init` building [ID3D12Resource; FRAME_COUNT] becomes
//     a plain loop that GetBuffer()s each back buffer and creates its RTV; the
//     owned raw pointers are stored in a CPointer<Unit> array.
//   • COM-pointer lifetimes: every long-lived interface pointer is released in
//     the sample's cleanup; GC owns the wrapper object, so no AddRef wrapping is
//     needed for cross-object references.
//   • A SIZE_T / pointer-sized integer is modelled by the ABI as CPointer<Unit>
//     (e.g. D3D12_SHADER_BYTECODE.BytecodeLength, ID3DBlob.GetBufferSize,
//     D3D12_CPU_DESCRIPTOR_HANDLE.ptr). We convert between it and UInt64 with
//     toUIntNative / handlePointerFromInt to do the byte arithmetic the
//     reference performs on usize.
// ============================================================================

// ---- Well-known IIDs (canonical string form) ------------------------------
const IID_ID3D12Device: String = "189819f1-1db6-4b57-be54-1821339b85f7"
const IID_IDXGIFactory4: String = "1bc6ea02-ef36-464f-bf0c-21ca39e5168a"
const IID_IDXGIAdapter1: String = "29038f61-3839-4626-91fd-086879011a05"
const IID_ID3D12CommandQueue: String = "0ec870a6-5d7e-4c22-8cfc-5baae07616ed"
const IID_IDXGISwapChain3: String = "94d99bdb-f1f8-4ab0-b236-7da0170edab1"
const IID_ID3D12DescriptorHeap: String = "8efb471d-616c-4f49-90f7-127bb763fa51"
const IID_ID3D12Resource: String = "696442be-a72e-4059-bc79-5b5c98040fad"
const IID_ID3D12CommandAllocator: String = "6102dee4-af59-4b09-b999-b44d73f09b24"
const IID_ID3D12RootSignature: String = "c54a6b66-72df-4ee8-8be5-a946a1429214"
const IID_ID3D12PipelineState: String = "765a30f3-f624-4c6f-a828-ace948622445"
const IID_ID3D12GraphicsCommandList: String = "5b160d0f-ac1b-4185-8ba8-b3ae42a5a455"
const IID_ID3D12Fence: String = "0a753dcf-c4d8-4b91-adf6-be5a60d95a76"

// ---- D3D12 / DXGI scalar constants (documented MSDN values) ---------------
const FRAME_COUNT: UInt32 = 2

const D3D_FEATURE_LEVEL_11_0: Int32 = 0xb000

const D3D12_COMMAND_LIST_TYPE_DIRECT: Int32 = 0

const DXGI_FORMAT_R8G8B8A8_UNORM: Int32 = 28
const DXGI_FORMAT_R32G32B32_FLOAT: Int32 = 6
const DXGI_FORMAT_R32G32B32A32_FLOAT: Int32 = 2

const DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt32 = 0x20
const DXGI_SWAP_EFFECT_FLIP_DISCARD: Int32 = 4
const DXGI_MWA_NO_ALT_ENTER: UInt32 = 0x2
const DXGI_ADAPTER_FLAG_SOFTWARE: UInt32 = 0x2

const D3D12_DESCRIPTOR_HEAP_TYPE_RTV: Int32 = 0

const D3D12_MIN_DEPTH: Float32 = 0.0
const D3D12_MAX_DEPTH: Float32 = 1.0

const D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT: Int32 = 0x1
const D3D_ROOT_SIGNATURE_VERSION_1: Int32 = 0x1

const D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA: Int32 = 0

const D3D12_FILL_MODE_SOLID: Int32 = 3
const D3D12_CULL_MODE_NONE: Int32 = 1

const D3D12_BLEND_ONE: Int32 = 2
const D3D12_BLEND_ZERO: Int32 = 1
const D3D12_BLEND_OP_ADD: Int32 = 1
const D3D12_LOGIC_OP_NOOP: Int32 = 0
const D3D12_COLOR_WRITE_ENABLE_ALL: UInt8 = 0x0f

const D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE: Int32 = 3
const D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST: Int32 = 4

const D3D12_HEAP_TYPE_UPLOAD: Int32 = 2
const D3D12_HEAP_FLAG_NONE: Int32 = 0
const D3D12_RESOURCE_DIMENSION_BUFFER: Int32 = 1
const D3D12_TEXTURE_LAYOUT_ROW_MAJOR: Int32 = 1
const D3D12_RESOURCE_STATE_GENERIC_READ: Int32 = 0x0ac3

const D3D12_RESOURCE_STATE_PRESENT: Int32 = 0
const D3D12_RESOURCE_STATE_RENDER_TARGET: Int32 = 0x4
const D3D12_RESOURCE_BARRIER_TYPE_TRANSITION: Int32 = 0
const D3D12_RESOURCE_BARRIER_FLAG_NONE: Int32 = 0
const D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES: UInt32 = 0xffff_ffff

const D3D12_FENCE_FLAG_NONE: Int32 = 0

const DXGI_CREATE_FACTORY_NONE: UInt32 = 0

const INFINITE: UInt32 = 0xffff_ffff

const UINT32_MAX: UInt32 = 0xffff_ffff

// ---- Window messages / styles ---------------------------------------------
const WM_PAINT: UInt32 = 0x000F
const WM_DESTROY: UInt32 = 0x0002
const WM_QUIT: UInt32 = 0x0012
const PM_REMOVE: UInt32 = 0x0001
const SW_SHOW: Int32 = 5
const CS_HREDRAW: UInt32 = 0x0002
const CS_VREDRAW: UInt32 = 0x0001
const WS_OVERLAPPEDWINDOW: UInt32 = 0x00CF_0000
const CW_USEDEFAULT: Int32 = -2147483648
const IDC_ARROW_ID: Int64 = 32512

const WIDTH: Int32 = 1280
const HEIGHT: Int32 = 720

// Vertex layout: position[3] + color[4], matching the reference's #[repr(C)].
const VERTEX_FLOATS: Int64 = 7

// ===========================================================================
// Small helpers.
// ===========================================================================

// QueryInterface a raw COM pointer for the given IID, returning the AddRef'd
// interface pointer or throwing E_NOINTERFACE (the reference's `cast::<T>()`).
func castRaw(source: CPointer<Unit>, iid: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(source, GUID.parse(iid)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }
}

// Release a raw COM pointer.
func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        if (vtblPtr.isNotNull()) {
            let vtbl = vtblPtr.read()
            let _ = vtbl.Release(raw)
        }
    }
}

// A SIZE_T value materialised as the pointer-sized integer the ABI expects.
func sizeToPtr(value: UInt64): CPointer<Unit> {
    return handlePointerFromInt(Int64(value))
}

// Offset a CPU descriptor handle pointer-value by `delta` bytes. The handle's
// `ptr` is a pointer-sized integer represented as CPointer<Unit>; add as ints.
func offsetHandle(base: CPointer<Unit>, delta: UInt64): CPointer<Unit> {
    let asInt = UInt64(base.toUIntNative()) + delta
    return handlePointerFromInt(Int64(asInt))
}

// ID3DBlob.GetBufferPointer() / GetBufferSize() through the blob vtbl.
func blobPointerAndSize(blob: CPointer<Unit>): (CPointer<Unit>, UInt64) {
    unsafe {
        let vtbl = CPointer<CPointer<ID3DBlobVtbl>>(blob).read().read()
        let ptr = vtbl.GetBufferPointer(blob)
        let len = vtbl.GetBufferSize(blob)
        return (ptr, UInt64(len.toUIntNative()))
    }
}

// transition_barrier helper: build a D3D12_RESOURCE_BARRIER for a state change.
func transitionBarrier(resource: CPointer<Unit>, before: Int32, after: Int32): D3D12_RESOURCE_BARRIER {
    var barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    var transition = D3D12_RESOURCE_TRANSITION_BARRIER()
    transition.pResource = resource
    transition.StateBefore = before
    transition.StateAfter = after
    transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.Anonymous.Transition = transition
    return barrier
}

// ===========================================================================
// The sample. A class so its mutable device-dependent state survives across
// the many messages a single window receives. All interface fields are owned
// raw COM pointers (null when not yet bound).
// ===========================================================================
class HelloTriangle {
    // Device-independent.
    var dxgiFactory: CPointer<Unit> = CPointer<Unit>() // IDXGIFactory4
    var device: CPointer<Unit> = CPointer<Unit>()      // ID3D12Device

    var handle: HWND = HWND()
    var useWarp: Bool = false

    // Device-dependent ("Resources" in the reference).
    var bound: Bool = false
    var commandQueue: CPointer<Unit> = CPointer<Unit>()    // ID3D12CommandQueue
    var swapChain: CPointer<Unit> = CPointer<Unit>()       // IDXGISwapChain3
    var frameIndex: UInt32 = 0
    var renderTargets: Array<CPointer<Unit>> = Array<CPointer<Unit>>(Int64(FRAME_COUNT), repeat: CPointer<Unit>())
    var rtvHeap: CPointer<Unit> = CPointer<Unit>()         // ID3D12DescriptorHeap
    var rtvDescriptorSize: UInt64 = 0
    var viewport: D3D12_VIEWPORT = D3D12_VIEWPORT()
    var scissorRect: RECT = RECT()
    var commandAllocator: CPointer<Unit> = CPointer<Unit>() // ID3D12CommandAllocator
    var rootSignature: CPointer<Unit> = CPointer<Unit>()    // ID3D12RootSignature
    var pso: CPointer<Unit> = CPointer<Unit>()              // ID3D12PipelineState
    var commandList: CPointer<Unit> = CPointer<Unit>()      // ID3D12GraphicsCommandList
    var vertexBuffer: CPointer<Unit> = CPointer<Unit>()     // ID3D12Resource (kept alive)
    var vbv: D3D12_VERTEX_BUFFER_VIEW = D3D12_VERTEX_BUFFER_VIEW()
    var fence: CPointer<Unit> = CPointer<Unit>()            // ID3D12Fence
    var fenceValue: UInt64 = 0
    var fenceEvent: HANDLE = HANDLE()

    init(useWarp: Bool) {
        this.useWarp = useWarp
        let (factory, dev) = createDevice(useWarp)
        dxgiFactory = factory
        device = dev
    }

    // ----- bind_to_window: build all device-dependent resources -----------
    func bindToWindow(hwnd: HWND): Unit {
        handle = hwnd

        // CreateCommandQueue(DIRECT).
        var queueDesc = D3D12_COMMAND_QUEUE_DESC()
        queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
        var queueRaw = CPointer<Unit>()
        var queueIid = GUID.parse(IID_ID3D12CommandQueue)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateCommandQueue(
                device,
                CPointer<Unit>(CPointer<D3D12_COMMAND_QUEUE_DESC>(inout queueDesc)),
                CPointer<Unit>(CPointer<GUID>(inout queueIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout queueRaw))
            )
            HRESULT(hr).check()
        }
        commandQueue = queueRaw

        // CreateSwapChainForHwnd then cast to IDXGISwapChain3.
        var swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
        swapChainDesc.BufferCount = FRAME_COUNT
        swapChainDesc.Width = UInt32(WIDTH)
        swapChainDesc.Height = UInt32(HEIGHT)
        swapChainDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM
        swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
        swapChainDesc.SampleDesc.Count = 1

        var swapChain1 = CPointer<Unit>()
        unsafe {
            let vtbl = factory4Vtbl()
            // CreateSwapChainForHwnd lives on IDXGIFactory2 (two base_ hops below
            // IDXGIFactory4: Factory4 -> Factory3 -> Factory2).
            let hr = vtbl.base_.base_.CreateSwapChainForHwnd(
                dxgiFactory,
                commandQueue,
                hwnd,
                CPointer<Unit>(CPointer<DXGI_SWAP_CHAIN_DESC1>(inout swapChainDesc)),
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout swapChain1))
            )
            HRESULT(hr).check()
        }
        swapChain = castRaw(swapChain1, IID_IDXGISwapChain3)
        releaseRaw(swapChain1)

        // MakeWindowAssociation(NO_ALT_ENTER) — on the IDXGIFactory base.
        unsafe {
            let vtbl = factory4Vtbl()
            // Factory4 -> Factory3 -> Factory2 -> Factory1 -> Factory.
            let hr = vtbl.base_.base_.base_.base_.MakeWindowAssociation(
                dxgiFactory, hwnd, DXGI_MWA_NO_ALT_ENTER)
            HRESULT(hr).check()
        }

        // frame_index = swap_chain.GetCurrentBackBufferIndex().
        unsafe {
            let vtbl = swapChain3Vtbl()
            frameIndex = vtbl.GetCurrentBackBufferIndex(swapChain)
        }

        // RTV descriptor heap.
        var heapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
        heapDesc.NumDescriptors = FRAME_COUNT
        heapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
        var heapRaw = CPointer<Unit>()
        var heapIid = GUID.parse(IID_ID3D12DescriptorHeap)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateDescriptorHeap(
                device,
                CPointer<Unit>(CPointer<D3D12_DESCRIPTOR_HEAP_DESC>(inout heapDesc)),
                CPointer<Unit>(CPointer<GUID>(inout heapIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout heapRaw))
            )
            HRESULT(hr).check()
        }
        rtvHeap = heapRaw

        unsafe {
            let vtbl = deviceVtbl()
            rtvDescriptorSize = UInt64(vtbl.GetDescriptorHandleIncrementSize(device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV))
        }

        // Create a render target view per frame.
        let rtvStart = cpuHandleStart()
        var resIid = GUID.parse(IID_ID3D12Resource)
        var i: Int64 = 0
        while (i < Int64(FRAME_COUNT)) {
            var rtRaw = CPointer<Unit>()
            unsafe {
                let vtbl = swapChainVtbl()
                let hr = vtbl.GetBuffer(
                    swapChain,
                    UInt32(i),
                    CPointer<Unit>(CPointer<GUID>(inout resIid)),
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout rtRaw))
                )
                HRESULT(hr).check()
            }
            var handleAt = D3D12_CPU_DESCRIPTOR_HANDLE()
            handleAt.ptr = offsetHandle(rtvStart, UInt64(i) * rtvDescriptorSize)
            unsafe {
                let vtbl = deviceVtbl()
                vtbl.CreateRenderTargetView(device, rtRaw, CPointer<Unit>(), handleAt)
            }
            renderTargets[i] = rtRaw
            i += 1
        }

        // Viewport / scissor.
        viewport.TopLeftX = 0.0
        viewport.TopLeftY = 0.0
        viewport.Width = Float32(WIDTH)
        viewport.Height = Float32(HEIGHT)
        viewport.MinDepth = D3D12_MIN_DEPTH
        viewport.MaxDepth = D3D12_MAX_DEPTH

        scissorRect.left = 0
        scissorRect.top = 0
        scissorRect.right = WIDTH
        scissorRect.bottom = HEIGHT

        // Command allocator.
        var allocRaw = CPointer<Unit>()
        var allocIid = GUID.parse(IID_ID3D12CommandAllocator)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateCommandAllocator(
                device,
                D3D12_COMMAND_LIST_TYPE_DIRECT,
                CPointer<Unit>(CPointer<GUID>(inout allocIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout allocRaw))
            )
            HRESULT(hr).check()
        }
        commandAllocator = allocRaw

        rootSignature = createRootSignature()
        pso = createPipelineState(rootSignature)

        // CreateCommandList(0, DIRECT, allocator, pso) -> ID3D12GraphicsCommandList.
        var listRaw = CPointer<Unit>()
        var listIid = GUID.parse(IID_ID3D12GraphicsCommandList)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateCommandList(
                device,
                0,
                D3D12_COMMAND_LIST_TYPE_DIRECT,
                commandAllocator,
                pso,
                CPointer<Unit>(CPointer<GUID>(inout listIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout listRaw))
            )
            HRESULT(hr).check()
        }
        commandList = listRaw

        // command_list.Close().
        unsafe {
            let vtbl = commandListVtbl()
            let hr = vtbl.Close(commandList)
            HRESULT(hr).check()
        }

        let aspectRatio = Float32(WIDTH) / Float32(HEIGHT)
        createVertexBuffer(aspectRatio)

        // Fence + event.
        var fenceRaw = CPointer<Unit>()
        var fenceIid = GUID.parse(IID_ID3D12Fence)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateFence(
                device,
                0,
                D3D12_FENCE_FLAG_NONE,
                CPointer<Unit>(CPointer<GUID>(inout fenceIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout fenceRaw))
            )
            HRESULT(hr).check()
        }
        fence = fenceRaw
        fenceValue = 1

        // CreateEventA(None, false, false, None).
        fenceEvent = unsafe {
            ThreadingApis.CreateEventA(CPointer<Unit>(), 0, 0, CPointer<UInt8>())
        }

        bound = true
    }

    // ----- per-frame render ----------------------------------------------
    func render(): Unit {
        if (!bound) {
            return
        }

        populateCommandList()

        // Execute the command list. ExecuteCommandLists takes an array of
        // ID3D12CommandList*; the graphics command list raw pointer is the
        // same COM object (its CommandList vtbl is a base of the graphics one).
        var listPtr = commandList
        unsafe {
            let vtbl = commandQueueVtbl()
            vtbl.ExecuteCommandLists(
                commandQueue,
                1,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout listPtr))
            )
        }

        // Present(1, 0).
        unsafe {
            let vtbl = swapChainVtbl()
            let hr = vtbl.Present(swapChain, 1, 0)
            HRESULT(hr).check()
        }

        waitForPreviousFrame()
    }

    func populateCommandList(): Unit {
        // Reset allocator + list.
        unsafe {
            let vtbl = commandAllocatorVtbl()
            let hr = vtbl.Reset(commandAllocator)
            HRESULT(hr).check()
        }
        unsafe {
            let vtbl = commandListVtbl()
            let hr = vtbl.Reset(commandList, commandAllocator, pso)
            HRESULT(hr).check()
        }

        // Set state. `inout` cannot target a class field, so the viewport /
        // scissor structs are copied into locals (the ABI only reads them).
        var localViewport = viewport
        var localScissor = scissorRect
        unsafe {
            let vtbl = commandListVtbl()
            vtbl.SetGraphicsRootSignature(commandList, rootSignature)
            vtbl.RSSetViewports(
                commandList, 1, CPointer<Unit>(CPointer<D3D12_VIEWPORT>(inout localViewport)))
            vtbl.RSSetScissorRects(
                commandList, 1, CPointer<Unit>(CPointer<RECT>(inout localScissor)))
        }

        // Transition: PRESENT -> RENDER_TARGET.
        var barrier = transitionBarrier(
            renderTargets[Int64(frameIndex)],
            D3D12_RESOURCE_STATE_PRESENT,
            D3D12_RESOURCE_STATE_RENDER_TARGET)
        unsafe {
            let vtbl = commandListVtbl()
            vtbl.ResourceBarrier(
                commandList, 1, CPointer<Unit>(CPointer<D3D12_RESOURCE_BARRIER>(inout barrier)))
        }

        // OMSetRenderTargets(1, &rtvHandle, false, None).
        var rtvHandle = D3D12_CPU_DESCRIPTOR_HANDLE()
        rtvHandle.ptr = offsetHandle(cpuHandleStart(), UInt64(frameIndex) * rtvDescriptorSize)
        unsafe {
            let vtbl = commandListVtbl()
            vtbl.OMSetRenderTargets(
                commandList,
                1,
                CPointer<Unit>(CPointer<D3D12_CPU_DESCRIPTOR_HANDLE>(inout rtvHandle)),
                0,
                CPointer<Unit>()
            )
        }

        // ClearRenderTargetView(handle, {0.0,0.2,0.4,1.0}, None).
        var clearColor = Array<Float32>(4, repeat: 0.0)
        clearColor[0] = 0.0
        clearColor[1] = 0.2
        clearColor[2] = 0.4
        clearColor[3] = 1.0
        unsafe {
            let colorHandle = acquireArrayRawData(clearColor)
            try {
                let vtbl = commandListVtbl()
                vtbl.ClearRenderTargetView(
                    commandList,
                    rtvHandle,
                    CPointer<Unit>(colorHandle.pointer),
                    0,
                    CPointer<Unit>()
                )
            } finally {
                releaseArrayRawData(colorHandle)
            }
        }

        // Draw the triangle. `inout` cannot target a class field, so the view
        // is copied into a local (IASetVertexBuffers only reads it).
        var localVbv = vbv
        unsafe {
            let vtbl = commandListVtbl()
            vtbl.IASetPrimitiveTopology(commandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
            vtbl.IASetVertexBuffers(
                commandList, 0, 1, CPointer<Unit>(CPointer<D3D12_VERTEX_BUFFER_VIEW>(inout localVbv)))
            vtbl.DrawInstanced(commandList, 3, 1, 0, 0)
        }

        // Transition: RENDER_TARGET -> PRESENT.
        var endBarrier = transitionBarrier(
            renderTargets[Int64(frameIndex)],
            D3D12_RESOURCE_STATE_RENDER_TARGET,
            D3D12_RESOURCE_STATE_PRESENT)
        unsafe {
            let vtbl = commandListVtbl()
            vtbl.ResourceBarrier(
                commandList, 1, CPointer<Unit>(CPointer<D3D12_RESOURCE_BARRIER>(inout endBarrier)))
            let hr = vtbl.Close(commandList)
            HRESULT(hr).check()
        }
    }

    func waitForPreviousFrame(): Unit {
        // Signal the fence.
        let fenceToWait = fenceValue
        unsafe {
            let vtbl = commandQueueVtbl()
            let hr = vtbl.Signal(commandQueue, fence, fenceToWait)
            HRESULT(hr).check()
        }
        fenceValue += 1

        // Wait until the previous frame is finished.
        var completed: UInt64 = 0
        unsafe {
            let vtbl = fenceVtbl()
            completed = vtbl.GetCompletedValue(fence)
        }
        if (completed < fenceToWait) {
            unsafe {
                let vtbl = fenceVtbl()
                let hr = vtbl.SetEventOnCompletion(fence, fenceToWait, fenceEvent)
                HRESULT(hr).check()
            }
            unsafe {
                ThreadingApis.WaitForSingleObject(fenceEvent, INFINITE)
            }
        }

        unsafe {
            let vtbl = swapChain3Vtbl()
            frameIndex = vtbl.GetCurrentBackBufferIndex(swapChain)
        }
    }

    // ----- resource creation helpers -------------------------------------

    // An empty root signature with input-assembler input layout allowed.
    func createRootSignature(): CPointer<Unit> {
        var desc = D3D12_ROOT_SIGNATURE_DESC()
        desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT

        var signatureBlob = CPointer<Unit>()
        unsafe {
            let hr = D3D12Apis.D3D12SerializeRootSignature(
                CPointer<Unit>(CPointer<D3D12_ROOT_SIGNATURE_DESC>(inout desc)),
                D3D_ROOT_SIGNATURE_VERSION_1,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout signatureBlob)),
                CPointer<Unit>()
            )
            HRESULT(hr).check()
        }

        var rootSig = CPointer<Unit>()
        var iid = GUID.parse(IID_ID3D12RootSignature)
        try {
            let (blobPtr, blobLen) = blobPointerAndSize(signatureBlob)
            unsafe {
                let vtbl = deviceVtbl()
                let hr = vtbl.CreateRootSignature(
                    device,
                    0,
                    blobPtr,
                    sizeToPtr(blobLen),
                    CPointer<Unit>(CPointer<GUID>(inout iid)),
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout rootSig))
                )
                HRESULT(hr).check()
            }
        } finally {
            releaseRaw(signatureBlob)
        }
        return rootSig
    }

    func createPipelineState(rootSig: CPointer<Unit>): CPointer<Unit> {
        // Release build: no debug/skip-optimisation compile flags.
        let compileFlags: UInt32 = 0

        let shadersPath = locateShaders()

        let vertexShader = compileShader(shadersPath, "VSMain", "vs_5_0", compileFlags)
        let pixelShader = compileShader(shadersPath, "PSMain", "ps_5_0", compileFlags)

        // Input element descriptors (POSITION, COLOR). The semantic name buffers
        // must stay pinned for the duration of the create call, so the whole PSO
        // creation runs inside the nested narrow-string closures.
        return narrowStringFactory("POSITION").withPtr { posName =>
            narrowStringFactory("COLOR").withPtr { colName =>
                var elems = Array<D3D12_INPUT_ELEMENT_DESC>(2, repeat: D3D12_INPUT_ELEMENT_DESC())

                var e0 = D3D12_INPUT_ELEMENT_DESC()
                e0.SemanticName = posName.asPtr()
                e0.SemanticIndex = 0
                e0.Format = DXGI_FORMAT_R32G32B32_FLOAT
                e0.InputSlot = 0
                e0.AlignedByteOffset = 0
                e0.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
                e0.InstanceDataStepRate = 0
                elems[0] = e0

                var e1 = D3D12_INPUT_ELEMENT_DESC()
                e1.SemanticName = colName.asPtr()
                e1.SemanticIndex = 0
                e1.Format = DXGI_FORMAT_R32G32B32A32_FLOAT
                e1.InputSlot = 0
                e1.AlignedByteOffset = 12
                e1.InputSlotClass = D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
                e1.InstanceDataStepRate = 0
                elems[1] = e1

                let result = unsafe {
                    let elemsHandle = acquireArrayRawData(elems)
                    try {
                        createPsoWithElements(rootSig, vertexShader, pixelShader,
                            CPointer<Unit>(elemsHandle.pointer))
                    } finally {
                        releaseArrayRawData(elemsHandle)
                    }
                }
                // The compiled shader blobs are referenced by the PSO during the
                // create call only; release our blob references afterwards.
                releaseRaw(vertexShader)
                releaseRaw(pixelShader)
                result
            }
        }
    }

    func createPsoWithElements(
        rootSig: CPointer<Unit>,
        vertexShader: CPointer<Unit>,
        pixelShader: CPointer<Unit>,
        elemsPtr: CPointer<Unit>
    ): CPointer<Unit> {
        var desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC()
        desc.InputLayout.pInputElementDescs = elemsPtr
        desc.InputLayout.NumElements = 2
        desc.pRootSignature = rootSig

        let (vsPtr, vsLen) = blobPointerAndSize(vertexShader)
        desc.VS.pShaderBytecode = vsPtr
        desc.VS.BytecodeLength = sizeToPtr(vsLen)

        let (psPtr, psLen) = blobPointerAndSize(pixelShader)
        desc.PS.pShaderBytecode = psPtr
        desc.PS.BytecodeLength = sizeToPtr(psLen)

        desc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID
        desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE

        // Blend state: render target 0 has the documented default-disabled blend.
        desc.BlendState.AlphaToCoverageEnable = 0
        desc.BlendState.IndependentBlendEnable = 0
        var rt0 = D3D12_RENDER_TARGET_BLEND_DESC()
        rt0.BlendEnable = 0
        rt0.LogicOpEnable = 0
        rt0.SrcBlend = D3D12_BLEND_ONE
        rt0.DestBlend = D3D12_BLEND_ZERO
        rt0.BlendOp = D3D12_BLEND_OP_ADD
        rt0.SrcBlendAlpha = D3D12_BLEND_ONE
        rt0.DestBlendAlpha = D3D12_BLEND_ZERO
        rt0.BlendOpAlpha = D3D12_BLEND_OP_ADD
        rt0.LogicOp = D3D12_LOGIC_OP_NOOP
        rt0.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL
        desc.BlendState.RenderTarget[0] = rt0

        desc.SampleMask = UINT32_MAX
        desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
        desc.NumRenderTargets = 1
        desc.SampleDesc.Count = 1
        desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM

        var psoRaw = CPointer<Unit>()
        var iid = GUID.parse(IID_ID3D12PipelineState)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateGraphicsPipelineState(
                device,
                CPointer<Unit>(CPointer<D3D12_GRAPHICS_PIPELINE_STATE_DESC>(inout desc)),
                CPointer<Unit>(CPointer<GUID>(inout iid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout psoRaw))
            )
            HRESULT(hr).check()
        }
        return psoRaw
    }

    // D3DCompileFromFile(path, None, None, entry, target, flags, 0, &code, None).
    func compileShader(path: String, entry: String, target: String, flags: UInt32): CPointer<Unit> {
        return wideStringFactory(path).withPtr { wpath =>
            narrowStringFactory(entry).withPtr { centry =>
                narrowStringFactory(target).withPtr { ctarget =>
                    var blob = CPointer<Unit>()
                    unsafe {
                        let hr = FxcApis.D3DCompileFromFile(
                            wpath.asPtr(),
                            CPointer<Unit>(),
                            CPointer<Unit>(),
                            centry.asPtr(),
                            ctarget.asPtr(),
                            flags,
                            0,
                            CPointer<Unit>(CPointer<CPointer<Unit>>(inout blob)),
                            CPointer<Unit>()
                        )
                        HRESULT(hr).check()
                    }
                    blob
                }
            }
        }
    }

    func createVertexBuffer(aspectRatio: Float32): Unit {
        // Triangle vertices: position (x,y,z) + color (r,g,b,a).
        let vertices: Array<Float32> = [
            0.0, 0.25 * aspectRatio, 0.0, 1.0, 0.0, 0.0, 1.0,
            0.25, -0.25 * aspectRatio, 0.0, 0.0, 1.0, 0.0, 1.0,
            -0.25, -0.25 * aspectRatio, 0.0, 0.0, 0.0, 1.0, 1.0
        ]
        let bufferSize: UInt64 = UInt64(vertices.size) * 4 // 4 bytes per Float32

        var heapProps = D3D12_HEAP_PROPERTIES()
        heapProps.Type = D3D12_HEAP_TYPE_UPLOAD

        var resourceDesc = D3D12_RESOURCE_DESC()
        resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
        resourceDesc.Width = bufferSize
        resourceDesc.Height = 1
        resourceDesc.DepthOrArraySize = 1
        resourceDesc.MipLevels = 1
        resourceDesc.SampleDesc.Count = 1
        resourceDesc.SampleDesc.Quality = 0
        resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR

        var bufferRaw = CPointer<Unit>()
        var iid = GUID.parse(IID_ID3D12Resource)
        unsafe {
            let vtbl = deviceVtbl()
            let hr = vtbl.CreateCommittedResource(
                device,
                CPointer<Unit>(CPointer<D3D12_HEAP_PROPERTIES>(inout heapProps)),
                D3D12_HEAP_FLAG_NONE,
                CPointer<Unit>(CPointer<D3D12_RESOURCE_DESC>(inout resourceDesc)),
                D3D12_RESOURCE_STATE_GENERIC_READ,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<GUID>(inout iid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout bufferRaw))
            )
            HRESULT(hr).check()
        }
        vertexBuffer = bufferRaw

        // Map, copy the vertex data, Unmap.
        var dataPtr = CPointer<Unit>()
        unsafe {
            let vtbl = resourceVtbl()
            let hr = vtbl.Map(
                vertexBuffer,
                0,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout dataPtr))
            )
            HRESULT(hr).check()
        }
        unsafe {
            let srcHandle = acquireArrayRawData(vertices)
            try {
                let dst = CPointer<Float32>(dataPtr)
                var k: Int64 = 0
                while (k < Int64(vertices.size)) {
                    (dst + k).write((srcHandle.pointer + k).read())
                    k += 1
                }
            } finally {
                releaseArrayRawData(srcHandle)
            }
        }
        unsafe {
            let vtbl = resourceVtbl()
            vtbl.Unmap(vertexBuffer, 0, CPointer<Unit>())
        }

        // Vertex buffer view.
        var gpuAddress: UInt64 = 0
        unsafe {
            let vtbl = resourceVtbl()
            gpuAddress = vtbl.GetGPUVirtualAddress(vertexBuffer)
        }
        vbv.BufferLocation = gpuAddress
        vbv.StrideInBytes = UInt32(VERTEX_FLOATS * 4)
        vbv.SizeInBytes = UInt32(bufferSize)
    }

    // ----- cleanup --------------------------------------------------------
    func cleanup(): Unit {
        var i: Int64 = 0
        while (i < Int64(FRAME_COUNT)) {
            releaseRaw(renderTargets[i])
            renderTargets[i] = CPointer<Unit>()
            i += 1
        }
        releaseRaw(fence)
        releaseRaw(commandList)
        releaseRaw(pso)
        releaseRaw(rootSignature)
        releaseRaw(commandAllocator)
        releaseRaw(vertexBuffer)
        releaseRaw(rtvHeap)
        releaseRaw(swapChain)
        releaseRaw(commandQueue)
        releaseRaw(device)
        releaseRaw(dxgiFactory)
    }

    // ----- vtbl accessors (read the vtbl out of the raw pointer) ----------
    func deviceVtbl(): ID3D12DeviceVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12DeviceVtbl>>(device).read().read()
        }
    }
    func factory4Vtbl(): IDXGIFactory4Vtbl {
        unsafe {
            return CPointer<CPointer<IDXGIFactory4Vtbl>>(dxgiFactory).read().read()
        }
    }
    func swapChain3Vtbl(): IDXGISwapChain3Vtbl {
        unsafe {
            return CPointer<CPointer<IDXGISwapChain3Vtbl>>(swapChain).read().read()
        }
    }
    // IDXGISwapChain base (Present / GetBuffer): SwapChain3 -> 2 -> 1 -> SwapChain.
    func swapChainVtbl(): IDXGISwapChainVtbl {
        unsafe {
            let v3 = CPointer<CPointer<IDXGISwapChain3Vtbl>>(swapChain).read().read()
            return v3.base_.base_.base_
        }
    }
    func commandQueueVtbl(): ID3D12CommandQueueVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12CommandQueueVtbl>>(commandQueue).read().read()
        }
    }
    func commandListVtbl(): ID3D12GraphicsCommandListVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12GraphicsCommandListVtbl>>(commandList).read().read()
        }
    }
    func commandAllocatorVtbl(): ID3D12CommandAllocatorVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12CommandAllocatorVtbl>>(commandAllocator).read().read()
        }
    }
    func resourceVtbl(): ID3D12ResourceVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12ResourceVtbl>>(vertexBuffer).read().read()
        }
    }
    func fenceVtbl(): ID3D12FenceVtbl {
        unsafe {
            return CPointer<CPointer<ID3D12FenceVtbl>>(fence).read().read()
        }
    }

    // rtv_heap.GetCPUDescriptorHandleForHeapStart().ptr (returned by value).
    func cpuHandleStart(): CPointer<Unit> {
        unsafe {
            let vtbl = CPointer<CPointer<ID3D12DescriptorHeapVtbl>>(rtvHeap).read().read()
            return vtbl.GetCPUDescriptorHandleForHeapStart(rtvHeap).ptr
        }
    }
}

// ===========================================================================
// Adapter selection / device creation (the reference's free functions).
// ===========================================================================

// Enumerate hardware adapters, skipping the software (Basic Render) adapter,
// returning the first that supports D3D12 (feature level 11_0). Owned pointer.
func getHardwareAdapter(factory: CPointer<Unit>): CPointer<Unit> {
    var i: UInt32 = 0
    while (true) {
        var adapter = CPointer<Unit>()
        let enumHr = unsafe {
            // EnumAdapters1 lives on IDXGIFactory1 (Factory4 -> 3 -> 2 -> 1).
            let vtbl = CPointer<CPointer<IDXGIFactory4Vtbl>>(factory).read().read()
            HRESULT(vtbl.base_.base_.base_.EnumAdapters1(
                factory, i, CPointer<Unit>(CPointer<CPointer<Unit>>(inout adapter))))
        }
        if (enumHr.isErr()) {
            // No more adapters (DXGI_ERROR_NOT_FOUND).
            break
        }

        var desc = DXGI_ADAPTER_DESC1()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIAdapter1Vtbl>>(adapter).read().read()
            let hr = vtbl.GetDesc1(adapter, CPointer<Unit>(CPointer<DXGI_ADAPTER_DESC1>(inout desc)))
            HRESULT(hr).check()
        }

        if ((desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) {
            // Skip the Basic Render Driver adapter.
            releaseRaw(adapter)
            i += 1
            continue
        }

        // Probe D3D12 support without creating the device (ppDevice = null).
        var probeIid = GUID.parse(IID_ID3D12Device)
        let ok = unsafe {
            HRESULT(D3D12Apis.D3D12CreateDevice(
                adapter,
                D3D_FEATURE_LEVEL_11_0,
                CPointer<Unit>(CPointer<GUID>(inout probeIid)),
                CPointer<Unit>()
            )).isOk()
        }
        if (ok) {
            return adapter
        }
        releaseRaw(adapter)
        i += 1
    }
    throw WindowsException(E_NOINTERFACE)
}

// create_device(): make the DXGI factory, pick the adapter, create the device.
func createDevice(useWarp: Bool): (CPointer<Unit>, CPointer<Unit>) {
    // Release build: no debug factory flag, no debug layer.
    var factoryRaw = CPointer<Unit>()
    var factoryIid = GUID.parse(IID_IDXGIFactory4)
    unsafe {
        let hr = DxgiApis.CreateDXGIFactory2(
            DXGI_CREATE_FACTORY_NONE,
            CPointer<Unit>(CPointer<GUID>(inout factoryIid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
        )
        HRESULT(hr).check()
    }

    let adapter = if (useWarp) {
        var warp = CPointer<Unit>()
        var warpIid = GUID.parse(IID_IDXGIAdapter1)
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIFactory4Vtbl>>(factoryRaw).read().read()
            let hr = vtbl.EnumWarpAdapter(
                factoryRaw,
                CPointer<Unit>(CPointer<GUID>(inout warpIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout warp))
            )
            HRESULT(hr).check()
        }
        warp
    } else {
        getHardwareAdapter(factoryRaw)
    }

    var deviceRaw = CPointer<Unit>()
    var deviceIid = GUID.parse(IID_ID3D12Device)
    unsafe {
        let hr = D3D12Apis.D3D12CreateDevice(
            adapter,
            D3D_FEATURE_LEVEL_11_0,
            CPointer<Unit>(CPointer<GUID>(inout deviceIid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout deviceRaw))
        )
        HRESULT(hr).check()
    }
    releaseRaw(adapter)

    return (factoryRaw, deviceRaw)
}

// Locate shaders.hlsl. The reference derives the path from current_exe() and
// joins "shaders.hlsl". Cangjie has no reliable current_exe here, so we probe
// the documented likely locations: alongside the running exe (when launched
// from target/release/bin the shader sits beside it after a copy, or the source
// tree is reachable by climbing up), the working directory, and the sample
// source directory — so the shader is found whichever way the sample is run.
func locateShaders(): String {
    let candidates: Array<String> = [
        // Beside the exe / working directory.
        "shaders.hlsl",
        // Working directory == sample root (e.g. when run via cjpm).
        "src/shaders.hlsl",
        // Working directory == target/release/bin: climb back to the source.
        "../../src/shaders.hlsl",
        "../../../src/shaders.hlsl",
        // Working directory == repository root.
        "samples/windows/direct3d12/src/shaders.hlsl"
    ]

    for (c in candidates) {
        if (exists(c)) {
            return c
        }
    }
    // Fall back to the first candidate; D3DCompileFromFile will surface the
    // error if it truly cannot be found.
    return candidates[0]
}

// ===========================================================================
// Command-line: detect -warp / /warp (case-insensitive).
// ===========================================================================
func buildUseWarp(): Bool {
    for (arg in getCommandLine()) {
        let lower = arg.toAsciiLower()
        if (lower == "-warp" || lower == "/warp") {
            return true
        }
    }
    return false
}

// ===========================================================================
// The single sample, held globally so the @C wndproc can reach it (the GC-safe
// analogue of the reference's GWLP_USERDATA self pointer).
// ===========================================================================
var gSample: Option<HelloTriangle> = None

@C
func wndproc(window: HWND, message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
    // WM_PAINT = 0x000F, WM_DESTROY = 0x0002. The reference also dispatches
    // WM_KEYUP/WM_KEYDOWN to no-op handlers and WM_CREATE to stash the self
    // pointer; with gSample published before creation and no key handling in
    // this sample, only paint + destroy need explicit handling.
    match (message) {
        case 0x000F =>
            match (gSample) {
                case Some(s) => s.render()
                case None => ()
            }
            return 0
        case 0x0002 =>
            unsafe { WndApis.PostQuitMessage(0) }
            return 0
        case _ =>
            return unsafe { WndApis.DefWindowProcA(window, message, wparam, lparam) }
    }
}

main(): Int64 {
    let useWarp = buildUseWarp()
    let sample = HelloTriangle(useWarp)
    gSample = Some(sample)

    // GetModuleHandleA(None).
    let instance = unsafe { LoaderApis.GetModuleHandleA(CPointer<UInt8>()) }
    let instancePtr = instance.Value

    let title = if (useWarp) {
        "D3D12 Hello Triangle (WARP)"
    } else {
        "D3D12 Hello Triangle"
    }

    return narrowStringFactory("RustWindowClass").withPtr { className =>
        narrowStringFactory(title).withPtr { titleName =>
            // LoadCursorW(None, IDC_ARROW).
            let cursor = unsafe {
                WndApis.LoadCursorW(HINSTANCE(), CPointer<UInt16>(handlePointerFromInt(IDC_ARROW_ID)))
            }

            var hinst = HINSTANCE()
            hinst.Value = instancePtr

            var wc = WNDCLASSEXA()
            wc.cbSize = UInt32(sizeOf<WNDCLASSEXA>())
            wc.style = CS_HREDRAW | CS_VREDRAW
            wc.lpfnWndProc = wndproc
            wc.hInstance = hinst
            wc.hCursor = cursor
            wc.lpszClassName = className.asPtr()

            let atom = unsafe {
                WndApis.RegisterClassExA(CPointer<Unit>(CPointer<WNDCLASSEXA>(inout wc)))
            }
            if (atom == 0) {
                return 1
            }

            // AdjustWindowRect for the desired client size.
            var windowRect = RECT()
            windowRect.left = 0
            windowRect.top = 0
            windowRect.right = WIDTH
            windowRect.bottom = HEIGHT
            unsafe {
                let _ = WndApis.AdjustWindowRect(
                    CPointer<Unit>(CPointer<RECT>(inout windowRect)),
                    WS_OVERLAPPEDWINDOW,
                    0
                )
            }

            let win = unsafe {
                WndApis.CreateWindowExA(
                    0,
                    className.asPtr(),
                    titleName.asPtr(),
                    WS_OVERLAPPEDWINDOW,
                    CW_USEDEFAULT,
                    CW_USEDEFAULT,
                    windowRect.right - windowRect.left,
                    windowRect.bottom - windowRect.top,
                    HWND(),
                    HMENU(),
                    hinst,
                    CPointer<Unit>()
                )
            }
            if (win.Value.isNull()) {
                return 1
            }

            sample.bindToWindow(win)
            unsafe { let _ = WndApis.ShowWindow(win, SW_SHOW) }

            // PeekMessage pump.
            var message = MSG()
            let msgPtr = unsafe { CPointer<Unit>(CPointer<MSG>(inout message)) }
            while (true) {
                if (unsafe { WndApis.PeekMessageA(msgPtr, HWND(), 0, 0, PM_REMOVE) } != 0) {
                    unsafe {
                        let _ = WndApis.TranslateMessage(msgPtr)
                        WndApis.DispatchMessageA(msgPtr)
                    }
                    if (message.message == WM_QUIT) {
                        break
                    }
                }
            }

            sample.cleanup()
            0
        }
    }
}
