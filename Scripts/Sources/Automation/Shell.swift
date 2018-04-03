import Foundation

class Shell {
    static func executeAndPrint(_ command: String, timeout: Double = 10, allowFailure: Bool = false) throws {
        print("$ \(command)")
        let output = try executeShell(commandPath: "/bin/bash", arguments: ["-c", command], timeout: timeout, allowFailure: allowFailure) {
            print($0, separator: "", terminator: "")
        }
        if let error = output?.error {
            print(error)
        }
    }

    static func execute(_ command: String, timeout: Double = 10, allowFailure: Bool = false) throws -> (output: String?, error: String?)? {
        return try executeShell(commandPath: "/bin/bash", arguments: ["-c", command], timeout: timeout, allowFailure: allowFailure)
    }

    static func bash(commandName: String,
                     arguments: [String] = [],
                     timeout: Double = 10,
                     allowFailure: Bool = false) throws -> (output: String?, error: String?)? {
        guard let execution = try? executeShell(commandPath: "/bin/bash" ,
                                                arguments: [ "-l", "-c", "/usr/bin/which \(commandName)" ],
                                                timeout: 1),
            var whichPathForCommand = execution?.output else { return nil }

        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        return try executeShell(commandPath: whichPathForCommand, arguments: arguments, timeout: timeout, allowFailure: allowFailure)
    }

    static func executeShell(commandPath: String,
                             arguments: [String] = [],
                             timeout: Double = 10,
                             allowFailure: Bool = false,
                             stream: @escaping (String) -> Void = { _ in }) throws -> (output: String?, error: String?)? {
        let task = Process()
        task.launchPath = commandPath
        task.arguments = arguments

        let pipeForOutput = Pipe()
        task.standardOutput = pipeForOutput

        let pipeForError = Pipe()
        task.standardError = pipeForError
        task.launch()

        let fileHandle = pipeForOutput.fileHandleForReading
        fileHandle.waitForDataInBackgroundAndNotify()

        var outputData = Data()

        func process(data: Data) {
            outputData.append(data)
            if let output = String(data: data, encoding: .utf8) {
                stream(output)
            }
        }

        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: fileHandle, queue: nil) { notification in
            if let noitificationFileHandle = notification.object as? FileHandle {
                process(data: noitificationFileHandle.availableData)
                noitificationFileHandle.waitForDataInBackgroundAndNotify()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        var shouldTimeout = false
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if task.isRunning {
                shouldTimeout = true
                task.terminate()
            }
        }

        task.waitUntilExit()

        process(data: fileHandle.readDataToEndOfFile())

        if shouldTimeout {
            throw CIError.timeout
        }

        let output = String(data: outputData, encoding: .utf8)

        let errorData = pipeForError.fileHandleForReading.readDataToEndOfFile()
        let error = String(data: errorData, encoding: .utf8)

        let exitCode = task.terminationStatus
        if exitCode > 0 && !allowFailure {
            throw CIError.invalidExitCode(statusCode: exitCode, errorOutput: error)
        }

        return (output, error)
    }

    static func env(name: String) -> String? {
        return ProcessInfo.processInfo.environment[name]
    }

    static func args() -> [String] {
        return ProcessInfo.processInfo.arguments
    }

    static func nextArg(_ arg: String) -> String? {
        if let index = Shell.args().index(of: arg), Shell.args().count > index + 1 {
            return Shell.args()[index.advanced(by: 1)]
        }
        return nil
    }
}
