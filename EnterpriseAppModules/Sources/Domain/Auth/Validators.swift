import Foundation

public enum Validators {
    public static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 254 else { return false }
        guard trimmed.contains("@"), trimmed.contains(".") else { return false }
        return true
    }

    public static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    public static func isValidDisplayName(_ displayName: String) -> Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

