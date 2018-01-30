import Foundation

class TravisCI {
    enum JobType: CustomStringConvertible {
        case local
        case travisAPI
        case travisCron
        case travisPushOnBranch(branch: String)
        case travisPushOnTag(name: String)
        case travisPullRequest(branch: String, sha: String, slug: String)

        var description: String {
            switch self {
            case .local:
                return "Local"
            case .travisAPI:
                return "Travis (API)"
            case .travisCron:
                return "Travis (Cron job)"
            case .travisPushOnBranch(let branch):
                return "Travis (Push on branch '\(branch)')"
            case .travisPushOnTag(let name):
                return "Travis (Push of tag '\(name)')"
            case .travisPullRequest(let branch):
                return "Travis (Pull Request on branch '\(branch)')"
            }
        }
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
        } else if let branch = Shell.env(name: "TRAVIS_BRANCH"), !branch.isEmpty {
            return .travisPushOnBranch(branch: branch)
        } else {
            fatalError("Cannot identify job type")
        }
    }
}
