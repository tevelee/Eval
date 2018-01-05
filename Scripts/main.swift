import Foundation

class Eval {
    static func main() {
        if TravisCI.isPullRquestJob() {
            runPullRequestLane()
        } else {
            runContinousIntegrationLane()
        }
    }
    
    static func runPullRequestLane() {
        runCommands {
            print("🎉 Building Pull Request")
            try prepareForBuild()
            try build()
            try runTests()
        }
    }

    static func runContinousIntegrationLane() {
        runCommands {
            print("🎉 Building CI")
            try prepareForBuild()
            try build()
            try runTests()
            try generateDocs()
            try publishDocs()
        }
    }
    
    static func runCommands(commands: () throws -> Void) {
        do {
            try commands()
            print("🎉 Finished successfully")
        } catch let ShellError.invalidExitCode(statusCode, errorOutput) {
            print("😢 Error happened: ", errorOutput ?? "unknown error")
            exit(statusCode)
        } catch {
            print("😢 Error happened")
            exit(-1)
        }
    }

    // MARK: Tasks

    static func prepareForBuild() throws {
        print("🤖 Generating project file")
        try Shell.executeAndPrint("swift package generate-xcodeproj")
    }

    static func build() throws {
        print("♻️ Building")
        try Shell.executeAndPrint("xcodebuild build -configuration Release -scheme Eval-Package | bundle exec xcpretty --color")
    }

    static func runTests() throws {
        print("👀 Running automated tests")
        try Shell.executeAndPrint("swift test")
    }

    static func generateDocs() throws {
        print("📚 Generating documentation")
        try Shell.executeAndPrint("bundle exec jazzy --config .jazzy.yml")
    }

    static func publishDocs() throws {
        print("📦 Publishing documentation")
        
        let dir = "gh-pages"
        defer {
            print("📦 ✨ Cleaning up")
            try! Shell.executeAndPrint("rm -rf " + dir)
        }
        
//        if TravisCI.isCIJob() {
//            let file = "github_rsa"
//            print("📦 ⏳ Setting up git credentials")
//            try Shell.executeAndPrint("openssl aes-256-cbc -K $encrypted_f50468713ad3_key -iv $encrypted_f50468713ad3_iv -in github_rsa.enc -out " + file + " -d")
//            try Shell.executeAndPrint("chmod 600 " + file)
//            try Shell.executeAndPrint("ssh-add " + file)
//            try Shell.executeAndPrint("git config --global user.email tevelee@gmail.com")
//            try Shell.executeAndPrint("git config --global user.name Travis-CI")
//        }

        if let repo = currentRepositoryUrl(ssh: true) {
            let branch = "gh-pages"
            print("📦 📥 Fetching previous docs")
            try Shell.executeAndPrint("git clone -b " + branch + " " + repo + " " + dir)
            print("📦 📄 Updating to the new one")
            try Shell.executeAndPrint("cp -Rf Documentation/Output/ " + dir)
            print("📦 👉 Committing")
            try Shell.executeAndPrint("git -C " + dir + " add .")
            try Shell.executeAndPrint("git -C " + dir + " commit -m 'Automatic documentation update'")
            try Shell.executeAndPrint("git -C " + dir + " add .")
            print("📦 📤 Pushing")
            try Shell.executeAndPrint("git -C " + dir + " push origin " + branch)
        }
    }

    // MARK: Helpers

    static func currentRepositoryUrl(dir: String = ".", ssh: Bool = false) -> String? {
        if let command = try? Shell.execute("git -C " + dir + " config --get remote.origin.url"), let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if ssh {
                return output.replacingOccurrences(of: "https://github.com/", with: "git@github.com:")
            } else {
                return output
            }
        }
        return nil
    }

    static func currentBranch(dir: String = ".") -> String? {
        if let command = try? Shell.execute("git -C " + dir + " rev-parse --abbrev-ref HEAD"), let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines) {
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

enum ShellError : Error {
    case invalidExitCode(statusCode: Int32, errorOutput: String?)
}

class Shell {
    static func executeAndPrint(_ command: String) throws {
        print("$ " + command)
        _ = try executeShell(commandPath: "/bin/bash" , arguments:["-c", command]) {
            print($0, separator: "", terminator: "")
        }
    }

    static func execute(_ command: String) throws -> (output: String?, error: String?)? {
        return try executeShell(commandPath: "/bin/bash" , arguments:["-c", command])
    }

    static func bash(commandName: String, arguments: [String] = []) throws -> (output: String?, error: String?)? {
        guard let execution = try? executeShell(commandPath: "/bin/bash" , arguments:[ "-l", "-c", "/usr/bin/which \(commandName)" ]),
            var whichPathForCommand = execution?.output else { return nil }
        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        return try executeShell(commandPath: whichPathForCommand, arguments: arguments)
    }

    static func executeShell(commandPath: String, arguments: [String] = [], stream: @escaping (String) -> Void = { _ in }) throws -> (output: String?, error: String?)? {
        let task = Process()
        task.launchPath = commandPath
        task.arguments = arguments

        let pipeForOutput = Pipe()
        task.standardOutput = pipeForOutput

        let pipeForError = Pipe()
        task.standardError = pipeForError
        task.launch()

        let fh = pipeForOutput.fileHandleForReading
        fh.waitForDataInBackgroundAndNotify()

        var outputData = Data()

        func process(data: Data) {
            outputData.append(data)
            if let output = String(data: data, encoding: .utf8) {
                stream(output)
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: fh, queue: nil) { notification in
            if let fh = notification.object as? FileHandle {
                process(data: fh.availableData)
                fh.waitForDataInBackgroundAndNotify()
            }
        }
        task.waitUntilExit()
        process(data: fh.readDataToEndOfFile())

        let output = String(data: outputData, encoding: .utf8)

        let errorData = pipeForError.fileHandleForReading.readDataToEndOfFile()
        let error = String(data: errorData, encoding: .utf8)

        let exitCode = task.terminationStatus
        if exitCode > 0 {
            throw ShellError.invalidExitCode(statusCode: exitCode, errorOutput: error)
        }

        return (output, error)
    }

    static func env(name: String) -> String? {
        return ProcessInfo.processInfo.environment[name]
    }
}

Eval.main()
