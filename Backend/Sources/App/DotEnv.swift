import Foundation

enum DotEnv {
    static func loadIfPresent() {
        let cwd = FileManager.default.currentDirectoryPath
        let path = (cwd as NSString).appendingPathComponent(".env")
        guard let data = FileManager.default.contents(atPath: path),
              let contents = String(data: data, encoding: .utf8) else {
            return
        }

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            guard let equalsIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !key.isEmpty else { continue }
            if ProcessInfo.processInfo.environment[key] != nil { continue }

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            setenv(key, value, 0)
        }
    }
}

