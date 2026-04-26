package windows_core

public func typeMarker<T>(): Option<T> {
    Option<T>.None
}

public func projectTypedAbi<T, A, D>(value: T, marker: Option<T>): A where T <: Type<T, A, D>, A <: CType {
    let _ = marker
    T.projectAbi(value)
}

public func assumeInitTypedAbi<T, A, D>(abi: A, marker: Option<T>): T where T <: Type<T, A, D> {
    let _ = marker
    assumeInitRef<T, A, D>(abi)
}

public func fromTypedAbi<T, A, D>(abi: A, marker: Option<T>): Result<T> where T <: Type<T, A, D> {
    let _ = marker
    fromAbi<T, A, D>(abi)
}

public func borrowOutSlotTypedAbi<T, A, D>(slot: OutSlot<T>, marker: Option<T>): CPointer<A> where T <: Type<T, A, D>, A <: CType {
    let _ = marker
    slot.borrowMut<A>()
}

public func takeOutSlotTypedAbi<T, A, D>(slot: OutSlot<T>, marker: Option<T>): ?A where T <: Type<T, A, D>, A <: CType {
    let _ = marker
    slot.takeAbi<A>()
}
