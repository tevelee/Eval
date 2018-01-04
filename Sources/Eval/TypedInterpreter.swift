import Foundation

public class TypedInterpreter : Interpreter {
    public typealias EvaluatedType = Any?
    
    public let context: InterpreterContext
    public lazy var interpreterForEvaluatingVariables: TypedInterpreter = { [unowned self] in self }()
    
    public let dataTypes: [DataTypeProtocol]
    public let functions: [FunctionProtocol]
    
    public init(dataTypes: [DataTypeProtocol] = [],
                functions: [FunctionProtocol] = [],
                context: InterpreterContext = InterpreterContext()) {
        self.dataTypes = dataTypes
        self.functions = functions
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> Any? {
        return evaluate(expression, context: InterpreterContext())
    }
    
    public func evaluate(_ expression: String, context: InterpreterContext) -> Any? {
        let context = self.context.merge(with: context)
        let expression = expression.trim()
        
        for dataType in dataTypes.reversed() {
            if let value = dataType.convert(input: expression, interpreter: self) {
                return value
            }
        }
        for variable in context.variables where expression == variable.key {
            return variable.value
        }
        for function in functions.reversed() {
            if let value = function.convert(input: expression, interpreter: self, context: context) {
                return value
            }
        }
        return nil
    }
    
    public func print(_ input: Any) -> String {
        for dataType in dataTypes {
            if let value = dataType.print(value: input) {
                return value
            }
        }
        return ""
    }
}

public protocol DataTypeProtocol {
    func convert(input: String, interpreter: TypedInterpreter) -> Any?
    func print(value input: Any) -> String?
}

public class DataType<T> : DataTypeProtocol {
    let type: T.Type
    let literals: [Literal<T>]
    let print: (T) -> String

    public init (type: T.Type,
                 literals: [Literal<T>],
                 print: @escaping (T) -> String) {
        self.type = type
        self.literals = literals
        self.print = print
    }
    
    public func convert(input: String, interpreter: TypedInterpreter) -> Any? {
        return literals.flatMap{ $0.convert(input: input, interpreter: interpreter) }.first
    }
    
    public func print(value input: Any) -> String? {
        guard let input = input as? T else { return nil }
        return self.print(input)
    }
}

public protocol FunctionProtocol {
    func convert(input: String, interpreter: TypedInterpreter, context: InterpreterContext) -> Any?
}

public class Function<T> : FunctionProtocol {
    var patterns: [Matcher<T, TypedInterpreter>]
    
    public init(patterns: [Matcher<T, TypedInterpreter>]) {
        self.patterns = patterns
    }
    
    public init(_ elements: [MatchElement], matcher: @escaping MatcherBlock<T, TypedInterpreter>) {
        self.patterns = [Matcher(elements, matcher: matcher)]
    }
    
    public func convert(input: String, interpreter: TypedInterpreter, context: InterpreterContext) -> Any? {
        guard case let .exactMatch(_, output, _) = matchStatement(amongst: patterns, in: input, until: input.count, interpreter: interpreter, context: context) else { return nil }
        return output
    }
}

public class Literal<T> {
    let convert: (String, TypedInterpreter) -> T?
    
    public init(convert: @escaping (String, TypedInterpreter) -> T?) {
        self.convert = convert
    }
    
    public init(_ check: String, convertsTo value: @autoclosure @escaping () -> T) {
        self.convert = { input,_ in check == input ? value() : nil }
    }
    
    public func convert(input: String, interpreter: TypedInterpreter) -> T? {
        return convert(input, interpreter)
    }
}

public class Variable<T> : GenericVariable<T, TypedInterpreter> {
}
