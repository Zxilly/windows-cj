package windows_metadata

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Real-winmd smoke test. Exercises the full reader path end-to-end against a
// genuine 7.4MB Windows.winmd: PE parse, table/heap access, TypeIndex build,
// TypeDef iteration, field/method enumeration, signature decode, custom
// attribute decode. Skips gracefully if the bundled winmd is unavailable so
// the build remains green on machines without it.
let SMOKE_WINMD_PATH = "winmd/Windows.winmd"

@Test
func smokeReadRealWinmd() {
    match (TypeIndex.read(SMOKE_WINMD_PATH)) {
        case None =>
            // Bundled winmd not present on this machine; treat as skipped.
            @Expect(true, true)
        case Some(index) =>
            // 1. There must be a large number of TypeDefs.
            let allTypes = index.iter()
            @Expect(allTypes.size > 1000, true)

            // 2. The assembly name must be readable.
            let file = index.getFile(0)
            @Expect(file.assemblyName().isSome(), true)

            // 3. Walk a slice of TypeDefs and force-decode their structure so any
            //    signature/attribute decoding bug surfaces.
            var examined = 0
            var fieldsSeen = 0
            var methodsSeen = 0
            var attrsSeen = 0
            for ((ns, nm, fileIdx, row) in allTypes) {
                if (examined >= 400) {
                    break
                }
                let ty = TypeDefRef(index, fileIdx, row)
                let _ = ty.flags()
                let _ = ty.category()
                @Expect(ty.name() == nm || trimTick(ty.name()) == nm, true)
                @Expect(ty.namespace() == ns, true)

                for (f in ty.fields()) {
                    let _ = f.name()
                    let _ = index.fieldType(fileIdx, f.row)
                    fieldsSeen += 1
                }
                for (m in ty.methods()) {
                    let _ = m.name()
                    let _ = index.methodDefSignature(fileIdx, m.row, Array<MetadataType>())
                    methodsSeen += 1
                    for (attrRow in m.attributes()) {
                        let _ = index.attributeName(fileIdx, attrRow)
                        attrsSeen += 1
                    }
                }
                examined += 1
            }
            @Expect(examined > 0, true)
    }
}
