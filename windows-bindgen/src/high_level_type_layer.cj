package windows_bindgen

import windows_metadata.*

// Explicit high-level WinRT type layer for projection code generation.
public func highLevelType(index: TypeIndex, ty: MetadataType): String {
    return winrtPublicType(index, ty)
}

public func highLevelAbiType(index: TypeIndex, ty: MetadataType): String {
    return winrtSlotType(index, ty)
}

public func highLevelArgumentExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    return winrtArgumentExpr(index, ty, expr)
}

public func highLevelNeedsInParam(index: TypeIndex, ty: MetadataType): Bool {
    return winrtNeedsInParam(index, ty)
}

public func highLevelThunkParamExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    return winrtThunkParamExpr(index, ty, expr)
}

public func highLevelReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    return winrtReturnExpr(index, ty, expr)
}

public func highLevelThunkReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    return winrtThunkReturnExpr(index, ty, expr)
}

public func highLevelHasResult(sig: MethodSignature): Bool {
    return winrtHasResult(sig)
}

public func highLevelResultDefaultExpr(typeName: String): String {
    return winrtResultDefaultExpr(typeName)
}

public func highLevelDefaultExpr(index: TypeIndex, ty: MetadataType): String {
    return winrtDefaultExpr(index, ty)
}
