import Foundation

enum CIError: Error {
    case invalidExitCode(statusCode: Int32, errorOutput: String?)
    case timeout
    case logicalError(message: String)
}
