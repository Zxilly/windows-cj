package windows_implement

import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*

class SchemaOnlyDummy {}

func schemaFactoryThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

func fakeVtbl(offset: Int64): CPointer<Unit> {
    unsafe { CPointer<Unit>(CPointer<UInt8>() + offset) }
}

@Test
func testSchemaOnlyCustomInterfacesRequireExplicitVtables() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.SchemaOnly",
        GUID.parse("55555555-5555-5555-5555-555555555555"),
        IUnknown.descriptorSchema(),
        "SchemaOnlyVtbl",
        "SchemaOnly",
        "SchemaOnly_Impl",
        []
    )

    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [schema])
    }), true)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [schema], CPointer<Unit>())
    }), true)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [schema], Array<CPointer<Unit>>(0, { _ => CPointer<Unit>() }))
    }), true)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [schema], [CPointer<Unit>()])
    }), true)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObject(SchemaOnlyDummy(), [schema.iid])
    }), true)
}

@Test
func testInheritedCustomInterfacesRequireLeafVtable() {
    let base = InterfaceDescriptorSchema(
        "Fixture.BaseSchema",
        GUID.parse("77777777-7777-7777-7777-777777777777"),
        IUnknown.descriptorSchema(),
        "BaseSchemaVtbl",
        "BaseSchema",
        "BaseSchema_Impl",
        []
    )
    let derived = InterfaceDescriptorSchema(
        "Fixture.DerivedSchema",
        GUID.parse("88888888-8888-8888-8888-888888888888"),
        base,
        "DerivedSchemaVtbl",
        "DerivedSchema",
        "DerivedSchema_Impl",
        []
    )
    let baseVtbl = fakeVtbl(0x1000)
    let derivedVtbl = fakeVtbl(0x2000)

    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [base, derived], [baseVtbl])
    }), true)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [base, derived], [baseVtbl, CPointer<Unit>()])
    }), true)

    let object = createComObjectFromSchemas(SchemaOnlyDummy(), [base, derived], [baseVtbl, derivedVtbl])
    let _ = object.releaseBase()
}

@Test
func testInheritedCustomInterfacesGroupThroughOmittedIntermediate() {
    let base = InterfaceDescriptorSchema(
        "Fixture.ChainBase",
        GUID.parse("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
        IUnknown.descriptorSchema(),
        "ChainBaseVtbl",
        "ChainBase",
        "ChainBase_Impl",
        []
    )
    let mid = InterfaceDescriptorSchema(
        "Fixture.ChainMid",
        GUID.parse("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"),
        base,
        "ChainMidVtbl",
        "ChainMid",
        "ChainMid_Impl",
        []
    )
    let leaf = InterfaceDescriptorSchema(
        "Fixture.ChainLeaf",
        GUID.parse("DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"),
        mid,
        "ChainLeafVtbl",
        "ChainLeaf",
        "ChainLeaf_Impl",
        []
    )
    let baseVtbl = fakeVtbl(0x5000)
    let leafVtbl = fakeVtbl(0x6000)

    @Expect(resolveSchemas([base, leaf])[0].slotIndex, 1)
    @Expect(resolveSchemas([base, leaf])[1].slotIndex, 1)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [base, leaf], [baseVtbl])
    }), true)

    let object = createComObjectFromSchemas(SchemaOnlyDummy(), [base, leaf], [baseVtbl, leafVtbl])
    var raw = CPointer<Unit>()
    let hr = object.queryInterfaceBase(base.iid, CPointer<CPointer<Unit>>(inout raw))
    @Expect(hr, S_OK)
    @Expect(raw.isNotNull(), true)
    let returnedVtbl = unsafe { CPointer<CPointer<Unit>>(raw).read() }
    @Expect(returnedVtbl.toUIntNative(), leafVtbl.toUIntNative())

    let _ = object.releaseBase()
    let _ = object.releaseBase()
}

@Test
func testDirectBaseIidSchemasGroupThroughListedIntermediate() {
    let base = InterfaceDescriptorSchema(
        "Fixture.LegacyBase",
        GUID.parse("12121212-1212-1212-1212-121212121212"),
        "IUnknown",
        IID_IUNKNOWN,
        "LegacyBaseVtbl",
        "LegacyBase",
        "LegacyBase_Impl",
        []
    )
    let mid = InterfaceDescriptorSchema(
        "Fixture.LegacyMid",
        GUID.parse("23232323-2323-2323-2323-232323232323"),
        "Fixture.LegacyBase",
        base.iid,
        "LegacyMidVtbl",
        "LegacyMid",
        "LegacyMid_Impl",
        []
    )
    let leaf = InterfaceDescriptorSchema(
        "Fixture.LegacyLeaf",
        GUID.parse("34343434-3434-3434-3434-343434343434"),
        "Fixture.LegacyMid",
        mid.iid,
        "LegacyLeafVtbl",
        "LegacyLeaf",
        "LegacyLeaf_Impl",
        []
    )
    let baseVtbl = fakeVtbl(0x7000)
    let midVtbl = fakeVtbl(0x8000)
    let leafVtbl = fakeVtbl(0x9000)

    let resolved = resolveSchemas([base, mid, leaf])
    @Expect(resolved[0].slotIndex, 1)
    @Expect(resolved[1].slotIndex, 1)
    @Expect(resolved[2].slotIndex, 1)
    @Expect(schemaFactoryThrows({ =>
        let _ = createComObjectFromSchemas(SchemaOnlyDummy(), [base, mid, leaf], [baseVtbl, midVtbl])
    }), true)

    let object = createComObjectFromSchemas(SchemaOnlyDummy(), [base, mid, leaf], [baseVtbl, midVtbl, leafVtbl])
    var raw = CPointer<Unit>()
    let hr = object.queryInterfaceBase(base.iid, CPointer<CPointer<Unit>>(inout raw))
    @Expect(hr, S_OK)
    @Expect(raw.isNotNull(), true)
    let returnedVtbl = unsafe { CPointer<CPointer<Unit>>(raw).read() }
    @Expect(returnedVtbl.toUIntNative(), leafVtbl.toUIntNative())

    let _ = object.releaseBase()
    let _ = object.releaseBase()
}

@Test
func testQueryInterfacePrefersExactDescriptorBeforeAncestorMatch() {
    let required = InterfaceDescriptorSchema(
        "Fixture.Required",
        GUID.parse("99999999-9999-9999-9999-999999999999"),
        IUnknown.descriptorSchema(),
        "RequiredVtbl",
        "Required",
        "Required_Impl",
        []
    )
    let owner = InterfaceDescriptorSchema(
        "Fixture.Owner",
        GUID.parse("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
        IInspectable.descriptorSchema(),
        ["Required"],
        [required.iid],
        "OwnerVtbl",
        "Owner",
        "Owner_Impl",
        []
    )
    let ownerVtbl = fakeVtbl(0x3000)
    let requiredVtbl = fakeVtbl(0x4000)

    let resolved = resolveSchemas([owner, required])
    @Expect(resolved[0].slotIndex != resolved[1].slotIndex, true)

    let ownerOnly = createComObjectFromSchemas(SchemaOnlyDummy(), [owner], ownerVtbl)
    var missingRaw = CPointer<Unit>()
    let missingHr = ownerOnly.queryInterfaceBase(required.iid, CPointer<CPointer<Unit>>(inout missingRaw))
    @Expect(missingHr, E_NOINTERFACE)
    @Expect(missingRaw.isNull(), true)
    let _ = ownerOnly.releaseBase()

    let object = createComObjectFromSchemas(SchemaOnlyDummy(), [owner, required], [ownerVtbl, requiredVtbl])

    var raw = CPointer<Unit>()
    let hr = object.queryInterfaceBase(required.iid, CPointer<CPointer<Unit>>(inout raw))
    @Expect(hr, S_OK)
    @Expect(raw.isNotNull(), true)
    let returnedVtbl = unsafe { CPointer<CPointer<Unit>>(raw).read() }
    @Expect(returnedVtbl.toUIntNative(), requiredVtbl.toUIntNative())

    let _ = object.releaseBase()
    let _ = object.releaseBase()
}
