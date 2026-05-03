package windows_bindgen.tokens

public interface ToTokens {
    func toTokens(tokens: TokenStream): Unit
}

public func toTokenStream(value: ToTokens): TokenStream {
    let tokens = TokenStream()
    value.toTokens(tokens)
    return tokens
}
