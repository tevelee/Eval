import Foundation
import PathKit
import xcproj

class Eval {
    static func main() {
        print("💁🏻‍♂️ Job type: \(TravisCI.jobType().description)")

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

            try prepareExamplesForBuild()
            try buildExamples()
            try runTestsOnExamples()

            try runLinter()
            try runDanger()
        }
    }

    static func runContinousIntegrationLane() {
        runCommands("Building CI") {
            try prepareForBuild()
            try build()
            try runTests()

            try prepareExamplesForBuild()
            try buildExamples()
            try runTestsOnExamples()

            try generateDocs()
            try publishDocs()

            try runLinter()
            try runCocoaPodsLinter()

            try testCoverage()

            try runDanger()
        }
    }

    static func isSpecificJob() -> Bool {
        guard let jobsString = Shell.nextArg("--jobs") else { return false }
        let jobsToRun = jobsString.split(separator: ",").map { String($0) }
        let jobsFound = jobsToRun.flatMap { job in jobs.first { $0.key == job } }
        runCommands("Executing jobs: \(jobsString)") {
            if let job = jobsToRun.first(where: { !self.jobs.keys.contains($0) }) {
                throw CIError.logicalError(message: "Job not found: \(job)")
            }
            try jobsFound.forEach {
                print("🏃🏻 Running job \($0.key)")
                try $0.value()
            }
        }
        return !jobsFound.isEmpty
    }

    static func runCommands(_ title: String, commands: () throws -> Void) {
        do {
            if !TravisCI.isRunningLocally() {
                print("travis_fold:start: \(title)")
            }

            print("ℹ️ \(title)")
            try commands()

            if !TravisCI.isRunningLocally() {
                print("travis_fold:end: \(title)")
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

    static let jobs: [String: () throws -> Void] = [
        "prepareForBuild": prepareForBuild,
        "prepareExamplesForBuild": prepareExamplesForBuild,
        "build": build,
        "buildExamples": buildExamples,
        "runTests": runTests,
        "runTestsOnExamples": runTestsOnExamples,
        "runLinter": runLinter,
        "generateDocs": generateDocs,
        "publishDocs": publishDocs,
        "runCocoaPodsLinter": runCocoaPodsLinter,
        "testCoverage": testCoverage,
        "runDanger": runDanger
    ]

    static func prepareForBuild() throws {
        if TravisCI.isRunningLocally() {
            print("🔦 Install dependencies")
            try Shell.executeAndPrint("rm -f Package.resolved")
            try Shell.executeAndPrint("rm -rf .build")
            try Shell.executeAndPrint("rm -rf build")
            try Shell.executeAndPrint("rm -rf Eval.xcodeproj")
            try Shell.executeAndPrint("bundle install")
        }

        print("🤖 Generating project file")
        try Shell.executeAndPrint("swift package generate-xcodeproj --enable-code-coverage")
    }

    static func build() throws {
        print("♻️ Building")
        try Shell.executeAndPrint("swift build", timeout: 120)
        try Shell.executeAndPrint("xcodebuild clean build -configuration Release -scheme Eval-Package | bundle exec xcpretty --color", timeout: 120)
    }

    static func runTests() throws {
        print("👀 Running automated tests")
        try Shell.executeAndPrint("swift test", timeout: 120)
        try Shell.executeAndPrint("xcodebuild test -configuration Release -scheme Eval-Package -enableCodeCoverage YES | bundle exec xcpretty --color", timeout: 120)
    }

    static func runLinter() throws {
        print("👀 Running linter")
        try Shell.executeAndPrint("swiftlint lint", timeout: 60)
    }

    static func generateDocs() throws {
        print("📚 Generating documentation")
        try Shell.executeAndPrint("bundle exec jazzy --config .jazzy.yml", timeout: 120)
    }

    static func publishDocs() throws {
        print("📦 Publishing documentation")

        let dir = "gh-pages"
        let file = "github_rsa"
        defer {
            print("📦 ✨ Cleaning up")
            try! Shell.executeAndPrint("rm -f \(file)")
            try! Shell.executeAndPrint("rm -rf \(dir)")
            try! Shell.executeAndPrint("rm -rf Documentation/Output")
        }

        if TravisCI.isRunningLocally() {
            print("📦 ✨ Preparing")
            try Shell.executeAndPrint("rm -rf \(dir)")
        }

        if let repo = currentRepositoryUrl()?.replacingOccurrences(of: "https://github.com/", with: "git@github.com:") {
            let branch = "gh-pages"

            print("📦 📥 Fetching previous docs")
            try Shell.executeAndPrint("git clone --depth 1 -b \(branch) \(repo) \(dir)", timeout: 30)

            print("📦 📄 Updating to the new one")
            try Shell.executeAndPrint("cp -Rf Documentation/Output/ \(dir)")

            print("📦 👉 Committing")
            try Shell.executeAndPrint("git -C \(dir) add .")
            try Shell.executeAndPrint("git -C \(dir) commit -m 'Automatic documentation update'")
            try Shell.executeAndPrint("git -C \(dir) add .")

            print("📦 📤 Pushing")
            let remote = "origin"
            try Shell.executeAndPrint("git -C \(dir) push \(remote) \(branch)", timeout: 30)
        } else {
            throw CIError.logicalError(message: "Repository URL not found")
        }
    }

    static func runCocoaPodsLinter() throws {
        print("🔮 Validating CocoaPods support")
        let flags = TravisCI.isRunningLocally() ? "--verbose" : ""
        try Shell.executeAndPrint("bundle exec pod lib lint \(flags)", timeout: 300)
    }

    static func testCoverage() throws {
        defer {
            print("📦 ✨ Cleaning up")
            try! Shell.executeAndPrint("rm -f Eval.framework.coverage.txt")
            try! Shell.executeAndPrint("rm -f EvalTests.xctest.coverage.txt")
        }

        print("☝🏻 Uploading code test coverage data")
        try Shell.executeAndPrint("bash <(curl -s https://codecov.io/bash) -J Eval", timeout: 120)
    }

    static func runDanger() throws {
        if TravisCI.isRunningLocally() {
            print("⚠️ Running Danger in local mode")
            try Shell.executeAndPrint("bundle exec danger pr --verbose || true", timeout: 120)
        } else if TravisCI.isPullRquestJob() {
            print("⚠️ Running Danger")
            try Shell.executeAndPrint("bundle exec danger --verbose || true", timeout: 120)
        }
    }

    static func prepareExamplesForBuild() throws {
        print("🤖 Generating project files for Examples")
        try onAllExamples { _ in
            let cleanup = [
                "rm -f Package.resolved",
                "rm -rf .build",
                "rm -rf build"
            ]
            let build = [
                "swift package generate-xcodeproj"
            ]
            return (cleanup + build).joined(separator: " && ")
        }

        try performManualSteps()
    }

    static func buildExamples() throws {
        print("♻️ Building Examples")
        try onAllExamples { example in
            "xcodebuild clean build -scheme \(example)-Package | bundle exec xcpretty --color"
        }
    }

    static func runTestsOnExamples() throws {
        print("👀 Running automated tests on Examples")
        try onAllExamples { example in
            "xcodebuild test -scheme \(example)-Package | bundle exec xcpretty --color"
        }
    }

    // MARK: Helpers

    static func onAllExamples(_ command: (String) throws -> String) throws {
        for (name, directory) in try examples() {
            let commands = [
                "pushd \(directory)",
                try command(name),
                "popd"
            ]
            try Shell.executeAndPrint(commands.joined(separator: " && "), timeout: 120)
        }
    }

    static func examples() throws -> [(name: String, directory: String)] {
        let directory = "Examples"
        return try FileManager.default.contentsOfDirectory(atPath: directory).map { ($0, "\(directory)/\($0)") }.filter { !$0.name.hasPrefix(".") }
    }

    static func currentRepositoryUrl(dir: String = ".") -> String? {
        if let command = try? Shell.execute("git -C \(dir) config --get remote.origin.url"),
            let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            return output
        }
        return nil
    }

    static func currentBranch(dir: String = ".") -> String? {
        if let command = try? Shell.execute("git -C \(dir) rev-parse --abbrev-ref HEAD"),
            let output = command?.output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            return output
        }
        return nil
    }

    // MARK: Manual steps

    static func performManualSteps() throws {
        try performManualStepsForTemplateExample()
    }

    static func performManualStepsForTemplateExample() throws {
        let example = "TemplateExample"
        print("⏳ Configuring \(example)")

        let base = Path("Examples/\(example)/")
        let path = Path("\(base)/\(example).xcodeproj")
        let project = try XcodeProj(path: path)

        let testsGroup = project.pbxproj.objects.groups.first { $0.value.name == "\(example)Tests" }

        let phase = PBXResourcesBuildPhase()
        let ref = project.pbxproj.objects.generateReference(phase, "CopyResourcesBuildPhase")
        project.pbxproj.objects.addObject(phase, reference: ref)

        if let target = project.pbxproj.objects.targets(named: "\(example)Tests").first {
            target.object.buildPhases.append(ref)
        }

        let tests = Path("\(base)/Tests/\(example)Tests")
        let files = try tests.children().flatMap { $0.components.last }.filter { $0.hasSuffix("txt") }
        for file in files {
            let fileRef = PBXFileReference(sourceTree: .group, name: nil, path: file)
            fileRef.fileEncoding = 4 //utf8
            let ref = project.pbxproj.objects.generateReference(fileRef, file)
            project.pbxproj.objects.fileReferences.append(fileRef, reference: ref)

            let buildFile = PBXBuildFile(fileRef: ref)
            let buildFileRef = project.pbxproj.objects.generateReference(buildFile, file)
            project.pbxproj.objects.buildFiles.append(buildFile, reference: buildFileRef)

            testsGroup?.value.children.append(ref)
            phase.files.append(buildFileRef)
        }

        try project.writePBXProj(path: path)
        print("🤖 Generated project file")
    }
}
