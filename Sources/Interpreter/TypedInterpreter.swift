import Foundation

public class TypedInterpreterBase: VariableEvaluator {
    public typealias EvaluatedType = Any?
    public typealias VariableEvaluator = TypedInterpreterBase
    
    public let context: InterpreterContext
    public lazy var interpreterForEvaluatingVariables: TypedInterpreterBase = { [unowned self] in self }()
    
    init(context: InterpreterContext) {
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> Any? {
        assertionFailure("Shouldn't reach this point. Specific subclass must override this `evaluate` method")
        return nil
    }
}

public class TypedInterpreter : TypedInterpreterBase {
    let dataTypes: [DataTypeProtocol]
    let functions: [FunctionProtocol]
    
    init(dataTypes: [DataTypeProtocol] = [],
         functions: [FunctionProtocol] = [],
         context: InterpreterContext) {
        self.dataTypes = dataTypes
        self.functions = functions
        super.init(context: context)
    }
    
    public override func evaluate(_ expression: String) -> Any? {
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
            if let value = function.convert(input: expression, interpreter: self) {
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
    func convert(input: String, interpreter: TypedInterpreterBase) -> Any?
    func print(value input: Any) -> String?
}

public class DataType<T> : DataTypeProtocol {
    let type: T.Type
    let literals: [Literal<T>]
    let print: (T) -> String

    init (type: T.Type,
          literals: [Literal<T>],
          print: @escaping (T) -> String) {
        self.type = type
        self.literals = literals
        self.print = print
    }
    
    public func convert(input: String, interpreter: TypedInterpreterBase) -> Any? {
        return literals.flatMap{ $0.convert(input: input, interpreter: interpreter) }.first
    }
    
    public func print(value input: Any) -> String? {
        guard let input = input as? T else { return nil }
        return self.print(input)
    }
}

public protocol FunctionProtocol {
    func convert(input: String, interpreter: TypedInterpreterBase) -> Any?
}

public class Function<T> : FunctionProtocol {
    var patterns: [Matcher<T, TypedInterpreterBase>]
    
    init(patterns: [Matcher<T, TypedInterpreterBase>]) {
        self.patterns = patterns
    }
    
    init(_ elements: [MatchElement], matcher: @escaping MatcherBlock<T, TypedInterpreterBase>) {
        self.patterns = [Matcher(elements, matcher: matcher)]
    }
    
    public func convert(input: String, interpreter: TypedInterpreterBase) -> Any? {
        guard case let .exactMatch(_, output, _) = matchStatement(amongst: patterns, in: input, until: input.count, interpreter: interpreter) else { return nil }
        return output
    }
}

public class Literal<T> {
    let convert: (String, TypedInterpreterBase) -> T?
    
    init(convert: @escaping (String, TypedInterpreterBase) -> T?) {
        self.convert = convert
    }
    
    init(_ check: String, convertsTo value: @autoclosure @escaping () -> T) {
        self.convert = { input,_ in check == input ? value() : nil }
    }
    
    public func convert(input: String, interpreter: TypedInterpreterBase) -> T? {
        return convert(input, interpreter)
    }
}

public class Variable<T> : GenericVariable<T, TypedInterpreter> {
}
