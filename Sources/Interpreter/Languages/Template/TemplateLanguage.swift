import Foundation

public struct RenderingContext {
    public typealias Function = ([String]) -> String
    
    public var variables: [String: Any]
    public var functions: [String: Function]
    
    public init(variables: [String: Any] = [:],
         functions: [String: Function] = [:]) {
        self.variables = variables
        self.functions = functions
    }
}

public class ContextAwareRenderer {
    public var context: RenderingContext
    
    public init(context: RenderingContext) {
        self.context = context
    }
    
    public func render(renderer: @escaping ([String: Any], InterpreterFactory?, inout RenderingContext) -> String) -> Renderer {
        return StaticRenderer { variables, interpreterFactory in renderer(variables, interpreterFactory, &self.context) }
    }
}
