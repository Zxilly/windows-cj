package windows_bindgen.tables

import windows_bindgen.tokens.*

public class TextArtifactTable <: ToTokens {
    public let name: String
    private let content_: TokenStream

    public init(name: String, content: TokenStream) {
        this.name = name
        this.content_ = content
    }

    public func toTokens(tokens: TokenStream): Unit {
        tokens.appendTokens(content_)
    }
}
