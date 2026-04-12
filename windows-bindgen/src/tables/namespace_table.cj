package windows_bindgen.tables

import std.collection.*
import windows_bindgen.tokens.*
import windows_bindgen.types.*

public class NamespaceTable <: ToTokens {
    public let namespace: String
    private let projectedTypes_: ArrayList<BindgenType>
    private let header_: TokenStream
    private let body_: TokenStream

    public init(
        namespace: String,
        projectedTypes: ArrayList<BindgenType>,
        header: TokenStream,
        body: TokenStream
    ) {
        this.namespace = namespace
        this.projectedTypes_ = projectedTypes
        this.header_ = header
        this.body_ = body
    }

    public func typeCount(): Int64 {
        var count: Int64 = 0
        for (ty in projectedTypes_) {
            if (bindgenTypeGeneratesCode(ty)) {
                count += 1
            }
        }
        return count
    }

    public func toTokens(tokens: TokenStream): Unit {
        tokens.appendTokens(header_)
        tokens.appendTokens(body_)
    }
}
