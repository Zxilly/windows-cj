package windows_result

// Result<T> — a value that is either a success (Ok) or a Windows error (Err).
// Use this when an operation may fail with a Windows error but you want the
// caller to decide how to handle it, rather than propagating an exception.
public enum Result<T> {
    | Ok(T)
    | Err(Error)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        !isOk()
    }

    // Returns the Ok value, or throws Exception if Err.
    public func unwrap(): T {
        match (this) {
            case Ok(value) => value
            case Err(error) => panic("called Result.unwrap() on an Err value: ${error}")
        }
    }

    // Returns the Ok value, or throws Exception with the given message prefix if Err.
    public func expect(message: String): T {
        match (this) {
            case Ok(value) => value
            case Err(error) => panic("${message}: ${error}")
        }
    }

    // Returns the Err value, or throws if Ok.
    public func unwrapErr(): Error {
        match (this) {
            case Ok(_) => throw Exception("called Result.unwrapErr() on an Ok value")
            case Err(error) => error
        }
    }

    // Returns the Err value, or throws with the given message prefix if Ok.
    public func expectErr(message: String): Error {
        match (this) {
            case Ok(_) => throw Exception("${message}: expected Err")
            case Err(error) => error
        }
    }

    public func map<R>(op: (T) -> R): Result<R> {
        match (this) {
            case Ok(value) => Result<R>.Ok(op(value))
            case Err(error) => Result<R>.Err(error)
        }
    }

    public func mapErr(op: (Error) -> Error): Result<T> {
        match (this) {
            case Ok(value) => Result<T>.Ok(value)
            case Err(error) => Result<T>.Err(op(error))
        }
    }

    public func andThen<R>(op: (T) -> Result<R>): Result<R> {
        match (this) {
            case Ok(value) => op(value)
            case Err(error) => Result<R>.Err(error)
        }
    }

    public func orElse(op: (Error) -> Result<T>): Result<T> {
        match (this) {
            case Ok(value) => Result<T>.Ok(value)
            case Err(error) => op(error)
        }
    }

    public func unwrapOr(default: T): T {
        match (this) {
            case Ok(value) => value
            case Err(_) => default
        }
    }

    public func unwrapOrElse(op: (Error) -> T): T {
        match (this) {
            case Ok(value) => value
            case Err(error) => op(error)
        }
    }

    public func ok(): Option<T> {
        match (this) {
            case Ok(value) => Some(value)
            case Err(_) => None
        }
    }

    public func err(): Option<Error> {
        match (this) {
            case Ok(_) => None
            case Err(error) => Some(error)
        }
    }
}

// Type aliases for code that uses different names for the HRESULT type.
type HResult = HRESULT
type ResultCode = HRESULT
