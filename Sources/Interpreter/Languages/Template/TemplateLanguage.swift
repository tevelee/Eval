import Foundation

public struct RenderingContext {
    public typealias Function = ([String]) -> String
    
    var variables: [String: Any]
    var functions: [String: Function]
    
    public init(variables: [String: Any] = [:],
         functions: [String: Function] = [:]) {
        self.variables = variables
        self.functions = functions
    }
}

public class ContextAwareRenderer {
    var context: RenderingContext
    
    public init(context: RenderingContext) {
        self.context = context
    }
    
    public func contextAwareRender(renderer: @escaping ([String: Any], inout RenderingContext) -> String?) -> StaticRenderer {
        return StaticRenderer { variables in renderer(variables, &self.context) ?? "" }
    }
}
