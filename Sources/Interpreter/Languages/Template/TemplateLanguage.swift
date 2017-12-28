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

public protocol ContextHandlerFeature: class, RenderingFeature {
    var context: RenderingContext { get set }
}

public class ContextHandler : ContextHandlerFeature {
    public var context: RenderingContext = RenderingContext()
    public weak var platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform) {
        self.platform = platform
    }
}
