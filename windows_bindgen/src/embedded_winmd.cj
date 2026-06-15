package windows_bindgen

import std.collection.*

let RT_RCDATA_RESOURCE_ID: Int64 = 10

// Win32 imports. x86_64 has a single calling convention, so no @CallingConv is
// needed (STDCALL is a no-op on x64; default CDECL maps to the Microsoft x64 ABI).
foreign {
    func GetModuleHandleW(lpModuleName: CPointer<UInt16>): CPointer<Unit>
    func FindResourceW(hModule: CPointer<Unit>, lpName: CPointer<UInt16>, lpType: CPointer<UInt16>): CPointer<Unit>
    func SizeofResource(hModule: CPointer<Unit>, hResInfo: CPointer<Unit>): UInt32
    func LoadResource(hModule: CPointer<Unit>, hResInfo: CPointer<Unit>): CPointer<Unit>
    func LockResource(hResData: CPointer<Unit>): CPointer<Unit>
}

class EmbeddedWinmdResourceInfo {
    let fileName: String
    let resourceId: Int64

    init(fileName: String, resourceId: Int64) {
        this.fileName = fileName
        this.resourceId = resourceId
    }
}

func embeddedWinmdResourceInfos(): ArrayList<EmbeddedWinmdResourceInfo> {
    let infos = ArrayList<EmbeddedWinmdResourceInfo>()
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.Foundation.winmd", 1000))
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.Graphics.winmd", 1001))
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.UI.Text.winmd", 1002))
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.UI.winmd", 1003))
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.UI.Xaml.winmd", 1004))
    infos.add(EmbeddedWinmdResourceInfo("Microsoft.Windows.ApplicationModel.Resources.winmd", 1005))
    infos.add(EmbeddedWinmdResourceInfo("Windows.Wdk.winmd", 1006))
    infos.add(EmbeddedWinmdResourceInfo("Windows.Win32.winmd", 1007))
    infos.add(EmbeddedWinmdResourceInfo("Windows.winmd", 1008))
    return infos
}

func loadEmbeddedWinmdFilesNative(): Option<ArrayList<WinmdFileRecord>> {
    let infos = embeddedWinmdResourceInfos()
    if (infos.isEmpty()) {
        return None
    }
    match (loadEmbeddedWinmdBytes(infos[0].resourceId)) {
        case Some(firstBytes) => return Some(loadEmbeddedWinmdFileRecordsFromFirst(infos, firstBytes))
        case None => return None
    }
}

func loadEmbeddedWinmdFileRecordsFromFirst(infos: ArrayList<EmbeddedWinmdResourceInfo>, firstBytes: Array<Byte>): ArrayList<WinmdFileRecord> {
    let records = ArrayList<WinmdFileRecord>()
    records.add(loadSingleWinmdBytesNative(infos[0].fileName, firstBytes, "embedded winmd resource: ${infos[0].fileName}"))
    var index: Int64 = 1
    while (index < Int64(infos.size)) {
        let info = infos[index]
        let bytes = match (loadEmbeddedWinmdBytes(info.resourceId)) {
            case Some(value) => value
            case None => throw Exception("embedded WinMD resource missing: ${info.fileName}")
        }
        records.add(loadSingleWinmdBytesNative(info.fileName, bytes, "embedded winmd resource: ${info.fileName}"))
        index += 1
    }
    return records
}

func loadEmbeddedWinmdBytes(resourceId: Int64): Option<Array<Byte>> {
    unsafe {
        let module = GetModuleHandleW(CPointer<UInt16>())
        if (module.isNull()) {
            return None
        }
        let resourceInfo = FindResourceW(module, makeIntResource(resourceId), makeIntResource(RT_RCDATA_RESOURCE_ID))
        if (resourceInfo.isNull()) {
            return None
        }
        let size = Int64(SizeofResource(module, resourceInfo))
        if (size <= 0) {
            return None
        }
        let resourceHandle = LoadResource(module, resourceInfo)
        if (resourceHandle.isNull()) {
            return None
        }
        let resourcePtr = CPointer<UInt8>(LockResource(resourceHandle))
        if (resourcePtr.isNull()) {
            return None
        }
        let bytes = Array<Byte>(size, { index => (resourcePtr + index).read() })
        return Some(bytes)
    }
}

func makeIntResource(value: Int64): CPointer<UInt16> {
    unsafe { CPointer<UInt16>(CPointer<UInt8>() + value) }
}
