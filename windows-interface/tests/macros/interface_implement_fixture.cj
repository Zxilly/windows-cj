package windows_interface_macro_fixture

import windows_core as windows_core
import windows_core.{ComObject, E_INVALIDARG, S_FALSE, S_OK}
import windows_interface as windows_interface
import windows_interface.macros.Interface
import windows_interface.macros.Implement

@Interface["11111111-1111-1111-1111-111111111111", "Fixture.Counter"]
public interface IFixtureCounter {
    func Count(value: UInt32): Int32
}

@Interface["22222222-2222-2222-2222-222222222222", "Fixture.Label"]
public interface IFixtureLabel {
    func Label(value: UInt32): Int32
}

@Interface["33333333-3333-3333-3333-333333333333", "Fixture.Base"]
public interface IFixtureBase {
    func BaseValue(value: UInt32): Int32
}

@Interface["44444444-4444-4444-4444-444444444444", "Fixture.Derived"]
public interface IFixtureDerived <: IFixtureBase {
    func DerivedValue(value: UInt32): Int32
}

@Interface["55555555-5555-5555-5555-555555555555", "Fixture.SecondBase"]
public interface IFixtureSecondBase {
    func SecondBaseValue(value: UInt32): Int32
}

@Interface["66666666-6666-6666-6666-666666666666", "Fixture.SecondDerived"]
public interface IFixtureSecondDerived <: IFixtureSecondBase {
    func SecondDerivedValue(value: UInt32): Int32
}

public interface FixtureMarker {
    func marker(): Bool
}

@Implement[IFixtureCounter]
public class FixtureCounter {
    public func Count(value: UInt32): Int32 {
        if (value == 7u32) {
            return S_FALSE.value
        }
        E_INVALIDARG.value
    }
}

@Implement[IFixtureCounter, IFixtureLabel]
public class CompositeFixtureCounter <: FixtureMarker {
    public func marker(): Bool {
        true
    }

    public func Count(value: UInt32): Int32 {
        if (value == 7u32) {
            return S_FALSE.value
        }
        E_INVALIDARG.value
    }

    public func Label(value: UInt32): Int32 {
        if (value == 3u32) {
            return S_OK.value
        }
        E_INVALIDARG.value
    }
}

@Implement[IFixtureBase, IFixtureDerived]
public class InheritedFixture {
    public func BaseValue(value: UInt32): Int32 {
        if (value == 11u32) {
            return S_OK.value
        }
        E_INVALIDARG.value
    }

    public func __winrtThunk_BaseValue(value: UInt32): Int32 {
        BaseValue(value)
    }

    public func DerivedValue(value: UInt32): Int32 {
        if (value == 13u32) {
            return S_FALSE.value
        }
        E_INVALIDARG.value
    }
}

@Implement[IFixtureSecondDerived]
public class InheritedDefaultThunkFixture {
    public func SecondBaseValue(value: UInt32): Int32 {
        if (value == 17u32) {
            return S_OK.value
        }
        E_INVALIDARG.value
    }

    public func SecondDerivedValue(value: UInt32): Int32 {
        if (value == 19u32) {
            return S_FALSE.value
        }
        E_INVALIDARG.value
    }
}

public func createFixtureCounter(): ComObject<FixtureCounter> {
    FixtureCounter().toComObject()
}

public func createCompositeFixtureCounter(): ComObject<CompositeFixtureCounter> {
    CompositeFixtureCounter().toComObject()
}

public func createInheritedFixture(): ComObject<InheritedFixture> {
    InheritedFixture().toComObject()
}

public func createInheritedDefaultThunkFixture(): ComObject<InheritedDefaultThunkFixture> {
    InheritedDefaultThunkFixture().toComObject()
}

main(): Int64 {
    if (IFixtureCounter.runtimeName() != "Fixture.Counter") {
        return 1
    }
    if (IFixtureCounter.projectionKind() != "interface") {
        return 1
    }
    let object = createFixtureCounter()
    var hr = S_OK
    try {
        let counter = object.toInterface(IFixtureCounter.descriptor())
        try {
            hr = unsafe { counter.Count(7u32) }
        } finally {
            counter.close()
        }
    } finally {
        let _ = object.releaseBase()
    }
    if (hr != S_FALSE) {
        return 1
    }

    let compositeObject = createCompositeFixtureCounter()
    var counterHr = S_OK
    var labelHr = S_OK
    try {
        let compositeCounter = compositeObject.toInterface(IFixtureCounter.descriptor())
        try {
            let compositeLabel = compositeObject.toInterface(IFixtureLabel.descriptor())
            try {
                counterHr = unsafe { compositeCounter.Count(7u32) }
                labelHr = unsafe { compositeLabel.Label(3u32) }
            } finally {
                compositeLabel.close()
            }
        } finally {
            compositeCounter.close()
        }
    } finally {
        let _ = compositeObject.releaseBase()
    }
    if (counterHr != S_FALSE || labelHr != S_OK) {
        return 1
    }

    let inheritedObject = createInheritedFixture()
    var baseHr = S_OK
    var derivedHr = S_OK
    try {
        let inheritedBase = inheritedObject.toInterface(IFixtureBase.descriptor())
        try {
            let inheritedDerived = inheritedObject.toInterface(IFixtureDerived.descriptor())
            try {
                baseHr = unsafe { inheritedBase.BaseValue(11u32) }
                derivedHr = unsafe { inheritedDerived.DerivedValue(13u32) }
            } finally {
                inheritedDerived.close()
            }
        } finally {
            inheritedBase.close()
        }
    } finally {
        let _ = inheritedObject.releaseBase()
    }
    if (baseHr != S_OK || derivedHr != S_FALSE) {
        return 1
    }

    let inheritedDefaultObject = createInheritedDefaultThunkFixture()
    var secondBaseHr = S_OK
    var secondDerivedHr = S_OK
    try {
        let inheritedDefaultBase = inheritedDefaultObject.toInterface(IFixtureSecondBase.descriptor())
        try {
            let inheritedDefaultDerived = inheritedDefaultObject.toInterface(IFixtureSecondDerived.descriptor())
            try {
                secondBaseHr = unsafe { inheritedDefaultBase.SecondBaseValue(17u32) }
                secondDerivedHr = unsafe { inheritedDefaultDerived.SecondDerivedValue(19u32) }
            } finally {
                inheritedDefaultDerived.close()
            }
        } finally {
            inheritedDefaultBase.close()
        }
    } finally {
        let _ = inheritedDefaultObject.releaseBase()
    }
    if (secondBaseHr != S_OK || secondDerivedHr != S_FALSE) {
        return 1
    }
    0
}
