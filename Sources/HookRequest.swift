import Foundation
import AppKit

enum HookEventType: String {
    case permissionRequest = "PermissionRequest"
    case notification = "Notification"
    case stop = "Stop"
}

struct HookRequest {
    let sessionId: String
    let toolName: String
    let toolInput: [String: Any]
    let cwd: String
    let permissionSuggestions: [[String: Any]]?
    let clientFD: Int32
    let eventType: HookEventType
    let message: String?

    var summary: String {
        if let cmd = toolInput["command"] as? String { return cmd }
        if let path = toolInput["file_path"] as? String {
            if let content = toolInput["content"] as? String {
                return "\(path)\n\n\(content)"
            }
            if let old = toolInput["old_string"] as? String,
               let new = toolInput["new_string"] as? String {
                return "\(path)\n\n--- old ---\n\(old)\n\n+++ new +++\n\(new)"
            }
            if let old = toolInput["old_string"] as? String {
                return "\(path)\n\nreplace: \(old)"
            }
            return path
        }
        if let query = toolInput["query"] as? String { return query }
        if let prompt = toolInput["prompt"] as? String { return prompt }
        if let url = toolInput["url"] as? String { return url }
        if let pattern = toolInput["pattern"] as? String { return "pattern: \(pattern)" }
        return toolInput.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    var shortSession: String { String(sessionId.prefix(8)) }

    var projectName: String { (cwd as NSString).lastPathComponent }

    private static let palette: [NSColor] = [
        NSColor(calibratedRed: 0.40, green: 0.85, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 0.70, green: 0.55, blue: 1.00, alpha: 1.0),
        NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.55, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.55, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.30, alpha: 1.0),
        NSColor(calibratedRed: 0.55, green: 0.80, blue: 1.00, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.80, alpha: 1.0),
        NSColor(calibratedRed: 0.50, green: 1.00, blue: 0.83, alpha: 1.0),
        NSColor(calibratedRed: 0.85, green: 0.70, blue: 1.00, alpha: 1.0),
    ]

    private static let dangerPatterns = [
        "rm -rf", "rm -fr", "rm -r ", "rmdir",
        "mkfs", "dd if=", "> /dev/", "fdisk",
        "chmod -R 777", "chmod 777", "chown -R",
        ":(){ :|:& };:",
        "--no-preserve-root",
        "git push --force", "git push -f", "git push origin +",
        "git reset --hard", "git clean -fd", "git checkout .",
        "git branch -D", "git rebase",
        "drop table", "drop database", "truncate table", "delete from",
        "pkill", "kill -9", "killall",
        "curl | sh", "curl | bash", "wget | sh", "wget | bash",
        "pip install", "npm install -g", "brew install",
        "> /etc/", "tee /etc/",
        "launchctl unload", "systemctl stop",
        "docker rm", "docker rmi", "docker system prune",
        "kubectl delete",
    ]

    var isDangerous: Bool {
        guard let cmd = toolInput["command"] as? String else { return false }
        let lower = cmd.lowercased()
        return HookRequest.dangerPatterns.contains { lower.contains($0) }
    }

    var alwaysLabel: String? {
        guard let suggestions = permissionSuggestions, !suggestions.isEmpty else { return nil }
        var parts: [String] = []
        for s in suggestions {
            switch s["type"] as? String {
            case "addRules":
                if let rules = s["rules"] as? [[String: Any]], let first = rules.first {
                    let tool = first["toolName"] as? String ?? ""
                    let rule = first["ruleContent"] as? String ?? ""
                    parts.append("\(tool) \(rule)")
                }
            case "addDirectories":
                if let dirs = s["directories"] as? [String] {
                    dirs.forEach { parts.append(($0 as NSString).lastPathComponent + "/") }
                }
            case "toolAlwaysAllow":
                parts.append(s["tool"] as? String ?? toolName)
            default:
                break
            }
        }
        if parts.isEmpty { return "Always allow" }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return "Always allow " + unique.joined(separator: ", ")
    }

    var projectColor: NSColor {
        var hash: UInt64 = 5381
        for byte in cwd.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return HookRequest.palette[Int(hash % UInt64(HookRequest.palette.count))]
    }
}

enum HookResponse {
    case allow
    case deny
    case allowAlways

    func toJSON(request: HookRequest) -> Data {
        var decision: [String: Any] = ["behavior": self == .deny ? "deny" : "allow"]
        if self == .deny {
            decision["message"] = "Denied via overlay"
        }
        if self == .allowAlways, let suggestions = request.permissionSuggestions, !suggestions.isEmpty {
            decision["updatedPermissions"] = suggestions
        }
        let result: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decision
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: result)) ?? Data()
    }
}
