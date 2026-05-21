import Foundation
import SharedModels

/// Registry + parser for the built-in slash command catalog used by ChatInputBar.
/// Each command has a `name`, `summary`, optional `usage` and `examples`, and an
/// executor closure that the input bar invokes.
public struct SlashCommandSpec: Identifiable, Hashable {
    public var id: String { name }
    public let name: String          // "task", "remind", "schedule", "status", "template", "me", "help"
    public let summary: String
    public let usage: String         // e.g. "/remind me in <duration> <text>"
    public let example: String?
}

public enum SlashCommandResult: Sendable {
    /// Don't send anything — the command handled itself (e.g. `/remind` created a reminder).
    case handled(message: String?)
    /// Replace the input body and send normally (e.g. `/me` reformats; `/template thx` expands).
    case rewriteAndSend(body: String)
    /// Open a sheet/picker keyed by name (caller resolves the actual sheet).
    case openSheet(name: String, prefill: [String: String])
    /// Parse error to surface inline.
    case invalid(reason: String)
}

@MainActor
public final class SlashCommandRegistry {
    public static let shared = SlashCommandRegistry()

    public let catalog: [SlashCommandSpec] = [
        SlashCommandSpec(name: "task",     summary: "Turn this message into a task",       usage: "/task <title>",                                       example: "/task Follow up with Acme"),
        SlashCommandSpec(name: "remind",   summary: "Set a reminder",                       usage: "/remind in <duration> <text>",                        example: "/remind in 2h send invoice"),
        SlashCommandSpec(name: "schedule", summary: "Schedule this message",                usage: "/schedule <when> <message>",                          example: "/schedule 9am Standup ready"),
        SlashCommandSpec(name: "status",   summary: "Set your custom status",               usage: "/status [emoji] <text>",                              example: "/status 🍔 Out to lunch"),
        SlashCommandSpec(name: "template", summary: "Insert a template by shortcut",        usage: "/template <shortcut>",                                example: "/template thx"),
        SlashCommandSpec(name: "me",       summary: "Send as an italic action",             usage: "/me <text>",                                          example: "/me waves"),
        SlashCommandSpec(name: "help",     summary: "Show available slash commands",        usage: "/help",                                                example: nil)
    ]

    private init() {}

    /// Returns `nil` if the input is not a slash command. Otherwise returns the
    /// `(spec, rest)` pair — `rest` is the everything-after-the-command string.
    public func parse(_ raw: String) -> (SlashCommandSpec, String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"), trimmed.count > 1 else { return nil }
        let stripped = trimmed.dropFirst()
        let parts = stripped.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let nameSub = parts.first else { return nil }
        let name = String(nameSub).lowercased()
        guard let spec = catalog.first(where: { $0.name == name }) else { return nil }
        let rest = parts.count > 1 ? String(parts[1]) : ""
        return (spec, rest)
    }

    /// Autocomplete candidates for a partial `/foo` input.
    public func matches(for prefix: String) -> [SlashCommandSpec] {
        let stripped = prefix.hasPrefix("/") ? String(prefix.dropFirst()) : prefix
        let lower = stripped.lowercased()
        guard !lower.isEmpty else { return catalog }
        return catalog.filter { $0.name.hasPrefix(lower) }
    }

    // MARK: - Time parsing helpers

    /// Parses a relative duration like "2h", "30m", "1d", "90s".
    public static func parseDuration(_ raw: String) -> TimeInterval? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard let idx = s.firstIndex(where: { !$0.isNumber }) else {
            return Double(s).map { $0 * 60 }  // bare number = minutes
        }
        let value = Double(s[..<idx]) ?? 0
        let unit = String(s[idx...])
        switch unit {
        case "s": return value
        case "m", "min", "mins": return value * 60
        case "h", "hr", "hrs": return value * 3600
        case "d", "day", "days": return value * 86_400
        case "w", "wk", "weeks": return value * 604_800
        default: return nil
        }
    }

    /// Parses "remind me in 2h <text>" or "remind in 2h <text>" → (durationSeconds, body).
    public static func parseRemind(_ rest: String) -> (Date, String)? {
        // Strip leading "me"
        var tokens = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if tokens.first?.lowercased() == "me" { tokens.removeFirst() }
        if tokens.first?.lowercased() == "in" { tokens.removeFirst() }
        guard let durationToken = tokens.first,
              let seconds = parseDuration(durationToken),
              tokens.count >= 2 else {
            return nil
        }
        let body = tokens.dropFirst().joined(separator: " ")
        guard !body.isEmpty else { return nil }
        return (Date().addingTimeInterval(seconds), body)
    }
}
