package windows_bindgen

import std.collection.*

// winmd_flag_names.cj
//
// Pure functions converting ECMA-335 metadata flag (bitfield) values into the
// exact string lists produced by the reference C# winmd-to-json tool. Two
// distinct conversion styles are reproduced here, mirroring the C# tool:
//
//   1. Hand-written, ordered enumeration (TypeAttributes, MethodAttributes,
//      MethodImplAttributes, MethodImportAttributes/PInvoke). These walk the
//      flags in a fixed, hand-coded order. Mutually-exclusive "mask" segments
//      (visibility, layout, calling convention, ...) are tested with
//      `(value & mask) == segmentValue`, so exactly one member per segment is
//      emitted.
//
//   2. .NET `[Flags] Enum.ToString()` replication (FieldAttributes,
//      ParameterAttributes, GenericParameterAttributes, EventAttributes,
//      PropertyAttributes). The C# tool calls `.Attributes.ToString().Split(", ")`
//      on these, so we reproduce the runtime's flags-format algorithm exactly:
//        - value 0  -> the zero-named member if present, else "0"
//        - otherwise greedily match non-zero members in DESCENDING value order,
//          subtracting matched bits; the emitted list is then reversed (giving
//          ascending value order). If bits remain unmatched, fall back to the
//          numeric value string (kept here for completeness, though it never
//          occurs for the well-formed winmd inputs).
//
// All numeric flag constants below are the fixed ECMA-335 / System.Reflection
// values; they are defined locally so this module stays independent of the
// metadata reader's internal enums.

// ---------------------------------------------------------------------------
// TypeAttributes (System.Reflection.TypeAttributes)
// ---------------------------------------------------------------------------
const TA_VISIBILITY_MASK: UInt32 = 0x0000_0007
const TA_NOT_PUBLIC: UInt32 = 0x0000_0000
const TA_PUBLIC: UInt32 = 0x0000_0001
const TA_NESTED_PUBLIC: UInt32 = 0x0000_0002
const TA_NESTED_PRIVATE: UInt32 = 0x0000_0003
const TA_NESTED_FAMILY: UInt32 = 0x0000_0004
const TA_NESTED_ASSEMBLY: UInt32 = 0x0000_0005
const TA_NESTED_FAM_AND_ASSEM: UInt32 = 0x0000_0006
const TA_NESTED_FAM_OR_ASSEM: UInt32 = 0x0000_0007

const TA_LAYOUT_MASK: UInt32 = 0x0000_0018
const TA_AUTO_LAYOUT: UInt32 = 0x0000_0000
const TA_SEQUENTIAL_LAYOUT: UInt32 = 0x0000_0008
const TA_EXPLICIT_LAYOUT: UInt32 = 0x0000_0010

const TA_CLASS_SEMANTICS_MASK: UInt32 = 0x0000_0020
const TA_CLASS: UInt32 = 0x0000_0000
const TA_INTERFACE: UInt32 = 0x0000_0020

const TA_ABSTRACT: UInt32 = 0x0000_0080
const TA_SEALED: UInt32 = 0x0000_0100
const TA_SPECIAL_NAME: UInt32 = 0x0000_0400
const TA_IMPORT: UInt32 = 0x0000_1000
const TA_WINDOWS_RUNTIME: UInt32 = 0x0000_4000

const TA_STRING_FORMAT_MASK: UInt32 = 0x0003_0000
const TA_ANSI_CLASS: UInt32 = 0x0000_0000
const TA_UNICODE_CLASS: UInt32 = 0x0001_0000
const TA_AUTO_CLASS: UInt32 = 0x0002_0000
const TA_CUSTOM_FORMAT_CLASS: UInt32 = 0x0003_0000

const TA_BEFORE_FIELD_INIT: UInt32 = 0x0010_0000
const TA_RT_SPECIAL_NAME: UInt32 = 0x0000_0800
const TA_HAS_SECURITY: UInt32 = 0x0004_0000

public func typeAttributesToStrings(value: UInt32): ArrayList<String> {
    let result = ArrayList<String>()

    // Visibility (mutually exclusive segment)
    let visibility = value & TA_VISIBILITY_MASK
    if (visibility == TA_NOT_PUBLIC) {
        result.add("NotPublic")
    } else if (visibility == TA_PUBLIC) {
        result.add("Public")
    } else if (visibility == TA_NESTED_PUBLIC) {
        result.add("NestedPublic")
    } else if (visibility == TA_NESTED_PRIVATE) {
        result.add("NestedPrivate")
    } else if (visibility == TA_NESTED_FAMILY) {
        result.add("NestedFamily")
    } else if (visibility == TA_NESTED_ASSEMBLY) {
        result.add("NestedAssembly")
    } else if (visibility == TA_NESTED_FAM_AND_ASSEM) {
        result.add("NestedFamANDAssem")
    } else if (visibility == TA_NESTED_FAM_OR_ASSEM) {
        result.add("NestedFamORAssem")
    }

    // Layout
    let layout = value & TA_LAYOUT_MASK
    if (layout == TA_AUTO_LAYOUT) {
        result.add("AutoLayout")
    } else if (layout == TA_SEQUENTIAL_LAYOUT) {
        result.add("SequentialLayout")
    } else if (layout == TA_EXPLICIT_LAYOUT) {
        result.add("ExplicitLayout")
    }

    // Class semantics
    let classSemantics = value & TA_CLASS_SEMANTICS_MASK
    if (classSemantics == TA_CLASS) {
        result.add("Class")
    } else if (classSemantics == TA_INTERFACE) {
        result.add("Interface")
    }

    // Independent bits (in C# order)
    if ((value & TA_ABSTRACT) != 0) {
        result.add("Abstract")
    }
    if ((value & TA_SEALED) != 0) {
        result.add("Sealed")
    }
    if ((value & TA_SPECIAL_NAME) != 0) {
        result.add("SpecialName")
    }
    if ((value & TA_IMPORT) != 0) {
        result.add("Import")
    }
    if ((value & TA_WINDOWS_RUNTIME) != 0) {
        result.add("WindowsRuntime")
    }

    // String format
    let stringFormat = value & TA_STRING_FORMAT_MASK
    if (stringFormat == TA_ANSI_CLASS) {
        result.add("AnsiClass")
    } else if (stringFormat == TA_UNICODE_CLASS) {
        result.add("UnicodeClass")
    } else if (stringFormat == TA_AUTO_CLASS) {
        result.add("AutoClass")
    } else if (stringFormat == TA_CUSTOM_FORMAT_CLASS) {
        result.add("CustomFormatClass")
    }

    if ((value & TA_BEFORE_FIELD_INIT) != 0) {
        result.add("BeforeFieldInit")
    }
    if ((value & TA_RT_SPECIAL_NAME) != 0) {
        result.add("RTSpecialName")
    }
    if ((value & TA_HAS_SECURITY) != 0) {
        result.add("HasSecurity")
    }

    return result
}

// ---------------------------------------------------------------------------
// MethodAttributes (System.Reflection.MethodAttributes)
// ---------------------------------------------------------------------------
const MA_MEMBER_ACCESS_MASK: UInt32 = 0x0000_0007
const MA_PRIVATE_SCOPE: UInt32 = 0x0000_0000
const MA_PRIVATE: UInt32 = 0x0000_0001
const MA_FAM_AND_ASSEM: UInt32 = 0x0000_0002
const MA_ASSEMBLY: UInt32 = 0x0000_0003
const MA_FAMILY: UInt32 = 0x0000_0004
const MA_FAM_OR_ASSEM: UInt32 = 0x0000_0005
const MA_PUBLIC: UInt32 = 0x0000_0006

const MA_STATIC: UInt32 = 0x0000_0010
const MA_FINAL: UInt32 = 0x0000_0020
const MA_VIRTUAL: UInt32 = 0x0000_0040
const MA_HIDE_BY_SIG: UInt32 = 0x0000_0080
const MA_CHECK_ACCESS_ON_OVERRIDE: UInt32 = 0x0000_0200

const MA_VTABLE_LAYOUT_MASK: UInt32 = 0x0000_0100
const MA_REUSE_SLOT: UInt32 = 0x0000_0000
const MA_NEW_SLOT: UInt32 = 0x0000_0100

const MA_ABSTRACT: UInt32 = 0x0000_0400
const MA_SPECIAL_NAME: UInt32 = 0x0000_0800
const MA_PINVOKE_IMPL: UInt32 = 0x0000_2000
const MA_UNMANAGED_EXPORT: UInt32 = 0x0000_0008
const MA_RT_SPECIAL_NAME: UInt32 = 0x0000_1000
const MA_HAS_SECURITY: UInt32 = 0x0000_4000
const MA_REQUIRE_SEC_OBJECT: UInt32 = 0x0000_8000

public func methodAttributesToStrings(value: UInt32): ArrayList<String> {
    let result = ArrayList<String>()

    // Member access (mutually exclusive segment)
    let access = value & MA_MEMBER_ACCESS_MASK
    if (access == MA_PRIVATE_SCOPE) {
        result.add("PrivateScope")
    } else if (access == MA_PRIVATE) {
        result.add("Private")
    } else if (access == MA_FAM_AND_ASSEM) {
        result.add("FamANDAssem")
    } else if (access == MA_ASSEMBLY) {
        result.add("Assembly")
    } else if (access == MA_FAMILY) {
        result.add("Family")
    } else if (access == MA_FAM_OR_ASSEM) {
        result.add("FamORAssem")
    } else if (access == MA_PUBLIC) {
        result.add("Public")
    }

    if ((value & MA_STATIC) != 0) {
        result.add("Static")
    }
    if ((value & MA_FINAL) != 0) {
        result.add("Final")
    }
    if ((value & MA_VIRTUAL) != 0) {
        result.add("Virtual")
    }
    if ((value & MA_HIDE_BY_SIG) != 0) {
        result.add("HideBySig")
    }
    if ((value & MA_CHECK_ACCESS_ON_OVERRIDE) != 0) {
        result.add("CheckAccessOnOverride")
    }

    // Vtable layout
    let vtableLayout = value & MA_VTABLE_LAYOUT_MASK
    if (vtableLayout == MA_REUSE_SLOT) {
        result.add("ReuseSlot")
    } else if (vtableLayout == MA_NEW_SLOT) {
        result.add("NewSlot")
    }

    if ((value & MA_ABSTRACT) != 0) {
        result.add("Abstract")
    }
    if ((value & MA_SPECIAL_NAME) != 0) {
        result.add("SpecialName")
    }
    if ((value & MA_PINVOKE_IMPL) != 0) {
        result.add("PinvokeImpl")
    }
    if ((value & MA_UNMANAGED_EXPORT) != 0) {
        result.add("UnmanagedExport")
    }
    if ((value & MA_RT_SPECIAL_NAME) != 0) {
        result.add("RTSpecialName")
    }
    if ((value & MA_HAS_SECURITY) != 0) {
        result.add("HasSecurity")
    }
    if ((value & MA_REQUIRE_SEC_OBJECT) != 0) {
        result.add("RequireSecObject")
    }

    return result
}

// ---------------------------------------------------------------------------
// MethodImplAttributes (System.Reflection.MethodImplAttributes)
// ---------------------------------------------------------------------------
const MIA_CODE_TYPE_MASK: UInt32 = 0x0000_0003
const MIA_IL: UInt32 = 0x0000_0000
const MIA_NATIVE: UInt32 = 0x0000_0001
const MIA_OPTIL: UInt32 = 0x0000_0002
const MIA_RUNTIME: UInt32 = 0x0000_0003

const MIA_MANAGED_MASK: UInt32 = 0x0000_0004
const MIA_UNMANAGED: UInt32 = 0x0000_0004
const MIA_MANAGED: UInt32 = 0x0000_0000

const MIA_FORWARD_REF: UInt32 = 0x0000_0010
const MIA_PRESERVE_SIG: UInt32 = 0x0000_0080
const MIA_INTERNAL_CALL: UInt32 = 0x0000_1000
const MIA_SYNCHRONIZED: UInt32 = 0x0000_0020
const MIA_NO_INLINING: UInt32 = 0x0000_0008
const MIA_AGGRESSIVE_INLINING: UInt32 = 0x0000_0100
const MIA_NO_OPTIMIZATION: UInt32 = 0x0000_0040
const MIA_AGGRESSIVE_OPTIMIZATION: UInt32 = 0x0000_0200

public func methodImplAttributesToStrings(value: UInt32): ArrayList<String> {
    let result = ArrayList<String>()

    // Code type
    let codeType = value & MIA_CODE_TYPE_MASK
    if (codeType == MIA_IL) {
        result.add("IL")
    } else if (codeType == MIA_NATIVE) {
        result.add("Native")
    } else if (codeType == MIA_OPTIL) {
        result.add("OPTIL")
    } else if (codeType == MIA_RUNTIME) {
        result.add("Runtime")
    }

    // Managed/Unmanaged
    let managed = value & MIA_MANAGED_MASK
    if (managed == MIA_UNMANAGED) {
        result.add("Unmanaged")
    } else if (managed == MIA_MANAGED) {
        result.add("Managed")
    }

    if ((value & MIA_FORWARD_REF) != 0) {
        result.add("ForwardRef")
    }
    if ((value & MIA_PRESERVE_SIG) != 0) {
        result.add("PreserveSig")
    }
    if ((value & MIA_INTERNAL_CALL) != 0) {
        result.add("InternalCall")
    }
    if ((value & MIA_SYNCHRONIZED) != 0) {
        result.add("Synchronized")
    }
    if ((value & MIA_NO_INLINING) != 0) {
        result.add("NoInlining")
    }
    if ((value & MIA_AGGRESSIVE_INLINING) != 0) {
        result.add("AggressiveInlining")
    }
    if ((value & MIA_NO_OPTIMIZATION) != 0) {
        result.add("NoOptimization")
    }
    if ((value & MIA_AGGRESSIVE_OPTIMIZATION) != 0) {
        result.add("AggressiveOptimization")
    }

    return result
}

// ---------------------------------------------------------------------------
// MethodImportAttributes / PInvoke (ImplMap MappingFlags)
// (System.Reflection.MethodImportAttributes)
//
// CallingConventionXxx strings are load-bearing: downstream model derives the
// FFI calling convention from them.
// ---------------------------------------------------------------------------
const MIM_NONE: UInt32 = 0x0000_0000
const MIM_EXACT_SPELLING: UInt32 = 0x0000_0001

const MIM_BEST_FIT_MAPPING_MASK: UInt32 = 0x0000_0030
const MIM_BEST_FIT_MAPPING_ENABLE: UInt32 = 0x0000_0010
const MIM_BEST_FIT_MAPPING_DISABLE: UInt32 = 0x0000_0020

const MIM_CHAR_SET_MASK: UInt32 = 0x0000_0006
const MIM_CHAR_SET_ANSI: UInt32 = 0x0000_0002
const MIM_CHAR_SET_UNICODE: UInt32 = 0x0000_0004
const MIM_CHAR_SET_AUTO: UInt32 = 0x0000_0006

const MIM_THROW_ON_UNMAPPABLE_CHAR_MASK: UInt32 = 0x0000_3000
const MIM_THROW_ON_UNMAPPABLE_CHAR_ENABLE: UInt32 = 0x0000_1000
const MIM_THROW_ON_UNMAPPABLE_CHAR_DISABLE: UInt32 = 0x0000_2000

const MIM_SET_LAST_ERROR: UInt32 = 0x0000_0040

const MIM_CALLING_CONVENTION_MASK: UInt32 = 0x0000_0700
const MIM_CALLING_CONVENTION_WIN_API: UInt32 = 0x0000_0100
const MIM_CALLING_CONVENTION_CDECL: UInt32 = 0x0000_0200
const MIM_CALLING_CONVENTION_STD_CALL: UInt32 = 0x0000_0300
const MIM_CALLING_CONVENTION_THIS_CALL: UInt32 = 0x0000_0400
const MIM_CALLING_CONVENTION_FAST_CALL: UInt32 = 0x0000_0500

public func pinvokeAttributesToStrings(value: UInt32): ArrayList<String> {
    let result = ArrayList<String>()

    // The C# tool emits "None" only when the whole value is exactly None.
    if (value == MIM_NONE) {
        result.add("None")
    }
    if ((value & MIM_EXACT_SPELLING) != 0) {
        result.add("ExactSpelling")
    }

    // Best-fit mapping
    let bestFit = value & MIM_BEST_FIT_MAPPING_MASK
    if (bestFit == MIM_BEST_FIT_MAPPING_ENABLE) {
        result.add("BestFitMappingEnable")
    } else if (bestFit == MIM_BEST_FIT_MAPPING_DISABLE) {
        result.add("BestFitMappingDisable")
    }

    // Char set
    let charSet = value & MIM_CHAR_SET_MASK
    if (charSet == MIM_CHAR_SET_ANSI) {
        result.add("CharSetAnsi")
    } else if (charSet == MIM_CHAR_SET_UNICODE) {
        result.add("CharSetUnicode")
    } else if (charSet == MIM_CHAR_SET_AUTO) {
        result.add("CharSetAuto")
    }

    // Throw on unmappable char
    let throwOnUnmappable = value & MIM_THROW_ON_UNMAPPABLE_CHAR_MASK
    if (throwOnUnmappable == MIM_THROW_ON_UNMAPPABLE_CHAR_ENABLE) {
        result.add("ThrowOnUnmappableCharEnable")
    } else if (throwOnUnmappable == MIM_THROW_ON_UNMAPPABLE_CHAR_DISABLE) {
        result.add("ThrowOnUnmappableCharDisable")
    }

    if ((value & MIM_SET_LAST_ERROR) != 0) {
        result.add("SetLastError")
    }

    // Calling convention (load-bearing for downstream model)
    let callingConvention = value & MIM_CALLING_CONVENTION_MASK
    if (callingConvention == MIM_CALLING_CONVENTION_WIN_API) {
        result.add("CallingConventionWinApi")
    } else if (callingConvention == MIM_CALLING_CONVENTION_CDECL) {
        result.add("CallingConventionCDecl")
    } else if (callingConvention == MIM_CALLING_CONVENTION_STD_CALL) {
        result.add("CallingConventionStdCall")
    } else if (callingConvention == MIM_CALLING_CONVENTION_THIS_CALL) {
        result.add("CallingConventionThisCall")
    } else if (callingConvention == MIM_CALLING_CONVENTION_FAST_CALL) {
        result.add("CallingConventionFastCall")
    }

    return result
}

// ---------------------------------------------------------------------------
// .NET [Flags] Enum.ToString() replication
//
// Members are passed in ASCENDING value order (the natural declaration order
// of the corresponding System.Reflection enums). The algorithm matches the
// .NET runtime's InternalFlagsFormat exactly.
// ---------------------------------------------------------------------------
struct FlagMember {
    let name: String
    let value: UInt64
    init(name: String, value: UInt64) {
        this.name = name
        this.value = value
    }
}

// Replicate System.Enum.ToString() for a [Flags] enum.
//   members: non-zero named members in ASCENDING value order.
//   zeroName: the name of the 0-valued member (e.g. "None"), or None if the
//             enum has no zero member (then a 0 value renders as "0").
func flagsToStrings(value: UInt64, members: Array<FlagMember>, zeroName: Option<String>): ArrayList<String> {
    let result = ArrayList<String>()

    if (value == 0) {
        match (zeroName) {
            case Some(n) => result.add(n)
            case None => result.add("0")
        }
        return result
    }

    // Greedy match from the largest member value down to the smallest,
    // collecting names; then reverse so the output is in ascending value order
    // (this mirrors the .NET runtime's flags formatter exactly).
    let matched = ArrayList<String>()
    var remaining = value
    var i = members.size - 1
    while (i >= 0) {
        let m = members[i]
        if (m.value != 0 && (remaining & m.value) == m.value) {
            remaining &= !m.value
            matched.add(m.name)
        }
        i -= 1
    }

    if (remaining != 0) {
        // Unmatched bits: .NET falls back to the plain numeric value string.
        result.add("${value}")
        return result
    }

    // Reverse matched (largest-first) into ascending-value order.
    var j = matched.size - 1
    while (j >= 0) {
        result.add(matched[j])
        j -= 1
    }
    return result
}

// ---------------------------------------------------------------------------
// FieldAttributes (System.Reflection.FieldAttributes)
//   FieldAccessMask = 0x7: PrivateScope=0, Private=1, FamANDAssem=2,
//   Assembly=3, Family=4, FamORAssem=5, Public=6
// ---------------------------------------------------------------------------
let FIELD_ATTR_MEMBERS: Array<FlagMember> = [
    // FieldAccessMask members (non-zero) in ascending value order
    FlagMember("Private", 0x0001),
    FlagMember("FamANDAssem", 0x0002),
    FlagMember("Assembly", 0x0003),
    FlagMember("Family", 0x0004),
    FlagMember("FamORAssem", 0x0005),
    FlagMember("Public", 0x0006),
    FlagMember("Static", 0x0010),
    FlagMember("InitOnly", 0x0020),
    FlagMember("Literal", 0x0040),
    FlagMember("NotSerialized", 0x0080),
    FlagMember("HasFieldRVA", 0x0100),
    FlagMember("SpecialName", 0x0200),
    FlagMember("RTSpecialName", 0x0400),
    FlagMember("HasFieldMarshal", 0x1000),
    FlagMember("PinvokeImpl", 0x2000),
    FlagMember("HasDefault", 0x8000)
]

public func fieldAttributesToStrings(value: UInt32): ArrayList<String> {
    // PrivateScope (0) is the zero-named member of FieldAttributes.
    return flagsToStrings(UInt64(value), FIELD_ATTR_MEMBERS, Some("PrivateScope"))
}

// ---------------------------------------------------------------------------
// ParameterAttributes (System.Reflection.ParameterAttributes)
//   None=0, In=1, Out=2, Lcid=4, Retval=8, Optional=0x10,
//   HasDefault=0x1000, HasFieldMarshal=0x2000
// ---------------------------------------------------------------------------
let PARAM_ATTR_MEMBERS: Array<FlagMember> = [
    FlagMember("In", 0x0001),
    FlagMember("Out", 0x0002),
    FlagMember("Lcid", 0x0004),
    FlagMember("Retval", 0x0008),
    FlagMember("Optional", 0x0010),
    FlagMember("HasDefault", 0x1000),
    FlagMember("HasFieldMarshal", 0x2000)
]

public func parameterAttributesToStrings(value: UInt32): ArrayList<String> {
    return flagsToStrings(UInt64(value), PARAM_ATTR_MEMBERS, Some("None"))
}

// ---------------------------------------------------------------------------
// GenericParameterAttributes (System.Reflection.GenericParameterAttributes)
//   None=0, Covariant=1, Contravariant=2 (VarianceMask=3),
//   ReferenceTypeConstraint=4, NotNullableValueTypeConstraint=8,
//   DefaultConstructorConstraint=0x10
// ---------------------------------------------------------------------------
let GENERIC_PARAM_ATTR_MEMBERS: Array<FlagMember> = [
    FlagMember("Covariant", 0x0001),
    FlagMember("Contravariant", 0x0002),
    FlagMember("ReferenceTypeConstraint", 0x0004),
    FlagMember("NotNullableValueTypeConstraint", 0x0008),
    FlagMember("DefaultConstructorConstraint", 0x0010)
]

public func genericParameterAttributesToStrings(value: UInt32): ArrayList<String> {
    return flagsToStrings(UInt64(value), GENERIC_PARAM_ATTR_MEMBERS, Some("None"))
}

// ---------------------------------------------------------------------------
// EventAttributes (System.Reflection.EventAttributes)
//   None=0, SpecialName=0x200, RTSpecialName=0x400
// ---------------------------------------------------------------------------
let EVENT_ATTR_MEMBERS: Array<FlagMember> = [
    FlagMember("SpecialName", 0x0200),
    FlagMember("RTSpecialName", 0x0400)
]

public func eventAttributesToStrings(value: UInt32): ArrayList<String> {
    return flagsToStrings(UInt64(value), EVENT_ATTR_MEMBERS, Some("None"))
}

// ---------------------------------------------------------------------------
// PropertyAttributes (System.Reflection.PropertyAttributes)
//   None=0, SpecialName=0x200, RTSpecialName=0x400, HasDefault=0x1000
// ---------------------------------------------------------------------------
let PROPERTY_ATTR_MEMBERS: Array<FlagMember> = [
    FlagMember("SpecialName", 0x0200),
    FlagMember("RTSpecialName", 0x0400),
    FlagMember("HasDefault", 0x1000)
]

public func propertyAttributesToStrings(value: UInt32): ArrayList<String> {
    return flagsToStrings(UInt64(value), PROPERTY_ATTR_MEMBERS, Some("None"))
}
