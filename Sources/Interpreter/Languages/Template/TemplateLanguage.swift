import Foundation

public struct RenderingContext {
    typealias Function = ([String]) -> String
    
    var variables: [String: String]
    var functions: [String: Function]
    
    init(variables: [String: String] = [:],
         functions: [String: Function] = [:]) {
        self.variables = variables
        self.functions = functions
    }
}

public class ContextAwareRenderer {
    var context: RenderingContext
    
    init(context: RenderingContext) {
        self.context = context
    }
    
    func contextAwareRender(renderer: @escaping ([String: String], inout RenderingContext) -> String?) -> StaticRenderer {
        return StaticRenderer { variables in renderer(variables, &self.context) ?? "" }
    }
}
