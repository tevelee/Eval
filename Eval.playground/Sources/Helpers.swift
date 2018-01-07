import Foundation
import Eval

public func infixOperator<A,B,T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
    return Function([Variable<A>("lhs", shortest: true), Keyword(symbol), Variable<B>("rhs", shortest: false)]) { arguments,_,_ in
        guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
        return body(lhs, rhs)
    }
}

public func prefixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
    return Function([Keyword(symbol), Variable<A>("value", shortest: false)]) { arguments,_,_ in
        guard let value = arguments["value"] as? A else { return nil }
        return body(value)
    }
}

public func suffixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
    return Function([Variable<A>("value", shortest: true), Keyword(symbol)]) { arguments,_,_ in
        guard let value = arguments["value"] as? A else { return nil }
        return body(value)
    }
}

public func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
    return Function([Keyword(name), Keyword("("), Variable<String>("arguments", shortest: true, interpreted: false), Keyword(")")]) { variables, interpreter, _ in
        guard let arguments = variables["arguments"] as? String else { return nil }
        let interpretedArguments = arguments.split(separator: ",").flatMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        return body(interpretedArguments)
    }
}

public func functionWithNamedParameters<T>(_ name: String, body: @escaping ([String: Any]) -> T?) -> Function<T> {
    return Function([Keyword(name), Keyword("("), Variable<String>("arguments", shortest: true, interpreted: false), Keyword(")")]) { variables, interpreter, _ in
        guard let arguments = variables["arguments"] as? String else { return nil }
        var interpretedArguments: [String: Any] = [:]
        for argument in arguments.split(separator: ",") {
            let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
            if let key = parts.first, let value = parts.last {
                interpretedArguments[String(key)] = interpreter.evaluate(String(value))
            }
        }
        return body(interpretedArguments)
    }
}

public func objectFunction<O,T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
    return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", shortest: false, interpreted: false) { value,_ in
        guard let value = value as? String, value == name else { return nil }
        return value
        }]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil else { return nil }
            return body(object)
    }
}

public func objectFunctionWithParameters<O,T>(_ name: String, body: @escaping (O, [Any]) -> T?) -> Function<T> {
    return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", interpreted: false) { value,_ in
        guard let value = value as? String, value == name else { return nil }
        return value
    }, Keyword("("), Variable<String>("arguments", interpreted: false), Keyword(")")]) { variables, interpreter, _ in
        guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
        let interpretedArguments = arguments.split(separator: ",").flatMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        return body(object, interpretedArguments)
    }
}

public func objectFunctionWithNamedParameters<O,T>(_ name: String, body: @escaping (O, [String: Any]) -> T?) -> Function<T> {
    return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", interpreted: false) { value,_ in
        guard let value = value as? String, value == name else { return nil }
        return value
    }, Keyword("("), Variable<String>("arguments", interpreted: false), Keyword(")")]) { variables, interpreter, _ in
        guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
        var interpretedArguments: [String: Any] = [:]
        for argument in arguments.split(separator: ",") {
            let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
            if let key = parts.first, let value = parts.last {
                interpretedArguments[String(key)] = interpreter.evaluate(String(value))
            }
        }
        return body(object, interpretedArguments)
    }
}
