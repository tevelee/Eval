import Foundation

class Eval {
    static func main() {
        if isSpecificJob() {
            return
        }
        
        if TravisCI.isPullRquestJob() || Shell.nextArg("--env") == "pr" {
            runPullRequestLane()
        } else {
            runContinousIntegrationLane()
        }
    }
    
    static func runPullRequestLane() {
        runCommands("Building Pull Request") {
            try prepareForBuild()
            try build()
            try runTests()
            try runLinter()
        }
    }

    static func runContinousIntegrationLane() {
        runCommands("Building CI") {
            try prepareForBuild()
            try build()
            try runTests()
            try runLinter()
            try generateDocs()
            try publishDocs()
            try runCocoaPodsLinter()
        }
    }
    
    static func isSpecificJob() -> Bool {
        guard let jobsString = Shell.nextArg("--jobs") else { return false }
        let jobsToRun = jobsString.split(separator: ",").map({ String($0) })
        let jobsFound = jobs.filter { jobsToRun.contains($0.key) }
        runCommands(jobsString) {
            if let job = jobsToRun.first(where: { !self.jobs.keys.contains($0) }) {
                throw CIError.logicalError(message: "Job not found: " + job)
            }
            try jobsFound.forEach {
                print("🏃🏻 Running job " + $0.key)
                try $0.value()
            }
        }
        return !jobsFound.isEmpty
    }
    
    static func runCommands(_ title: String, commands: () throws -> Void) {
        do {
            print("ℹ️ " + title)
            
            if !TravisCI.isRunningLocally() {
                print("travis_fold:start:" + title)
                print("travis_time_start")
            }
            
            try commands()
            
            if !TravisCI.isRunningLocally() {
                print("travis_time_finish")
                print("travis_fold:end:" + title)
            }
            
            print("🎉 Finished successfully")
        } catch let CIError.invalidExitCode(statusCode, errorOutput) {
            print("😢 Error happened: [InsufficientExitCode] ", errorOutput ?? "unknown error")
            exit(statusCode)
        } catch let CIError.logicalError(message) {
            print("😢 Error happened: [LogicalError] ", message)
            exit(-1)
        } catch CIError.timeout {
            print("🕙 Timeout")
            exit(-1)
        } catch {
            print("😢 Error happened [General]")
            exit(-1)
        }
    }

    // MARK: Tasks
    
    static let jobs = [
        "prepareForBuild": prepareForBuild,
        "build": build,
        "runTests": runTests,
        "runLinter": runLinter,
        "generateDocs": generateDocs,
        "publishDocs": publishDocs,
        "runCocoaPodsLinter": runCocoaPodsLinter,
    ]

    static func prepareForBuild() throws {
        if TravisCI.isRunningLocally() {
            print("🔦 Install dependencies")
            try Shell.executeAndPrint("bundle install")
        }
        
        print("🤖 Generating project file")
        try Shell.executeAndPrint("swift package generate-xcodeproj")
    }

    static func build() throws {
        print("♻️ Building")
        try Shell.executeAndPrint("swift build", timeout: 30)
        try Shell.executeAndPrint("xcodebuild clean build -configuration Release -scheme Eval-Package | bundle exec xcpretty --color", timeout: 30)
    }

    static func runTests() throws {
        print("👀 Running automated tests")
        try Shell.executeAndPrint("swift test", timeout: 60)
        try Shell.executeAndPrint("xcodebuild test -configuration Release -scheme Eval-Package | bundle exec xcpretty --color", timeout: 60)
    }
    
    static func runLinter() throws {
        print("👀 Running linter")
        try Shell.executeAndPrint("swiftlint lint", timeout: 10)
    }

    static func generateDocs() throws {
        print("📚 Generating documentation")
        try Shell.executeAndPrint("bundle exec jazzy --config .jazzy.yml", timeout: 60)
    }

    static func publishDocs() throws {
        print("📦 Publishing documentation")
        
        let dir = "gh-pages"
        let file = "github_rsa"
        defer {
            print("📦 ✨ Cleaning up")
            try! Shell.executeAndPrint("rm -f " + file)
            try! Shell.executeAndPrint("rm -rf " + dir)
        }
        
        if TravisCI.isRunningLocally() {
            print("📦 ✨ Preparing")
            try! Shell.executeAndPrint("rm -rf " + dir)
        }
        
        if TravisCI.isCIJob() {
            print("📦 ⏳ Setting up git credentials")
            try Shell.executeAndPrint("openssl aes-256-cbc -K $encrypted_f50468713ad3_key -iv $encrypted_f50468713ad3_iv -in github_rsa.enc -out " + file + " -d")
            try Shell.executeAndPrint("chmod 600 " + file)
//            try Shell.executeAndPrint("sudo ssh -o StrictHostKeyChecking=no git@github.com || true")
            if let result = try Shell.bash(commandName: "sudo", arguments: ["ssh", "-o", "StrictHostKeyChecking=no", "git@github.com"], allowFailure: true), let errorOutput = result.error {
                print(errorOutput)
            }
            try Shell.executeAndPrint("ssh-add " + file)
            try Shell.executeAndPrint("git config --global user.email tevelee@gmail.com")
            try Shell.executeAndPrint("git config --global user.name 'Travis CI'")
        }

        if let repo = currentRepositoryUrl()?.replacingOccurrences(of: "https://github.com/", with: "git@github.com:") {
            let branch = "gh-pages"

            print("📦 📥 Fetching previous docs")
            try Shell.executeAndPrint("git clone --depth 1 -b " + branch + " " + repo + " " + dir)

            print("📦 📄 Updating to the new one")
            try Shell.executeAndPrint("cp -Rf Documentation/Output/ " + dir)

            print("📦 👉 Committing")
            try Shell.executeAndPrint("git -C " + dir + " add .")
            try Shell.executeAndPrint("git -C " + dir + " commit -m 'Automatic documentation update'")
            try Shell.executeAndPrint("git -C " + dir + " add .")

            print("📦 📤 Pushing")
            try Shell.executeAndPrint("git -C " + dir + " push origin " + branch, timeout: 30)
        } else {
            throw CIError.logicalError(message: "Repository URL not found")
        }
    }
    
    static func runCocoaPodsLinter() throws {
        print("🔮 Validating CocoaPods support")
        let flags = TravisCI.isRunningLocally() ? " --verbose" : ""
        try Shell.executeAndPrint("pod lib lint" + flags, timeout: 120)
    }

    // MARK: Helpers

    static func currentRepositoryUrl(dir: String = ".") -> String? {
        if let command = try? Shell.execute("git -C " + dir + " config --get remote.origin.url"),
            let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            return output
        }
        return nil
    }

    static func currentBranch(dir: String = ".") -> String? {
        if let command = try? Shell.execute("git -C " + dir + " rev-parse --abbrev-ref HEAD"),
            let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            return output
        }
        return nil
    }
}

class TravisCI {
    enum JobType {
        case local
        case travisAPI
        case travisCron
        case travisPushOnBranch(branch: String)
        case travisPushOnTag(name: String)
        case travisPullRequest(branch: String, sha: String, slug: String)
    }
    
    static func isPullRquestJob() -> Bool {
        return Shell.env(name: "TRAVIS_EVENT_TYPE") == "pull_request"
    }
    
    static func isRunningLocally() -> Bool {
        return Shell.env(name: "TRAVIS") != "true"
    }
    
    static func isCIJob() -> Bool {
        return !isRunningLocally() && !isPullRquestJob()
    }
    
    static func jobType() -> JobType {
        if isRunningLocally() {
            return .local
        } else if isPullRquestJob() {
            return .travisPullRequest(branch: Shell.env(name: "TRAVIS_PULL_REQUEST_BRANCH") ?? "",
                                      sha: Shell.env(name: "TRAVIS_PULL_REQUEST_SHA") ?? "",
                                      slug: Shell.env(name: "TRAVIS_PULL_REQUEST_SLUG") ?? "")
        } else if Shell.env(name: "TRAVIS_EVENT_TYPE") == "cron" {
            return .travisCron
        } else if Shell.env(name: "TRAVIS_EVENT_TYPE") == "api" {
            return .travisAPI
        } else if let tag = Shell.env(name: "TRAVIS_TAG"), !tag.isEmpty {
            return .travisPushOnTag(name: tag)
        } else {
            return .travisPushOnBranch(branch: "TRAVIS_BRANCH")
        }
    }
}

enum CIError : Error {
    case invalidExitCode(statusCode: Int32, errorOutput: String?)
    case timeout
    case logicalError(message: String)
}

class Shell {
    static func executeAndPrint(_ command: String, timeout: Double = 10, allowFailure: Bool = false) throws {
        print("$ " + command)
        let output = try executeShell(commandPath: "/bin/bash" , arguments:["-c", command], timeout: timeout, allowFailure: allowFailure) {
            print($0, separator: "", terminator: "")
        }
        if let error = output?.error {
            print(error)
        }
    }

    static func execute(_ command: String, timeout: Double = 10, allowFailure: Bool = false) throws -> (output: String?, error: String?)? {
        return try executeShell(commandPath: "/bin/bash" , arguments:["-c", command], timeout: timeout, allowFailure: allowFailure)
    }

    static func bash(commandName: String,
                     arguments: [String] = [],
                     timeout: Double = 10,
                     allowFailure: Bool = false) throws -> (output: String?, error: String?)? {
        guard let execution = try? executeShell(commandPath: "/bin/bash" ,
                                                arguments:[ "-l", "-c", "/usr/bin/which \(commandName)" ],
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

        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: fileHandle, queue: nil) { notification in
            if let fh = notification.object as? FileHandle {
                process(data: fh.availableData)
                fh.waitForDataInBackgroundAndNotify()
            }
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

Eval.main()
