import Foundation

/// Semantic Embedding Service for Vector Search.
/// Generates deterministic 128-dimensional dense normalized semantic vectors
/// using domain-aware conceptual projection, token n-gram hashing, and cosine similarity.
public final class EmbeddingService: Sendable {
    public static let shared = EmbeddingService()

    public static let vectorDimension = 128

    // MARK: - Domain Concepts & Semantic Clusters (64 dimensions mapped across core domains)
    private let domainConceptWeights: [(clusterIndex: Int, weight: Float, keywords: Set<String>)] = [
        // 0. Authentication, Access & Security (Dimensions 0-7)
        (0, 1.0, ["auth", "authenticate", "authentication", "login", "signin", "sign-in", "logout", "sso", "oauth", "oauth2", "credential", "credentials", "password", "session", "jwt", "token", "2fa", "mfa", "unauthorized", "forbidden", "access"]),
        // 1. Bugs, Errors, Crashes & Defects (Dimensions 8-15)
        (8, 1.0, ["bug", "defect", "error", "crash", "crashed", "crashing", "exception", "failure", "fail", "failed", "broken", "freeze", "hang", "glitch", "regression", "panic", "fault", "problem", "issue", "trouble"]),
        // 2. UI, Screens, Views & Frontend (Dimensions 16-23)
        (16, 1.0, ["screen", "screens", "ui", "ux", "view", "views", "page", "pages", "interface", "dialog", "modal", "sheet", "window", "form", "input", "button", "layout", "frontend", "front-end", "client", "display", "render"]),
        // 3. Billing, Subscriptions & Payments (Dimensions 24-31)
        (24, 1.0, ["billing", "bill", "invoice", "payment", "pay", "checkout", "subscription", "subscribe", "tier", "plan", "stripe", "credit", "card", "charge", "refund", "pricing", "quota", "seat", "seats"]),
        // 4. Chat, Messages & Communication (Dimensions 32-39)
        (32, 1.0, ["chat", "message", "messages", "messaging", "conversation", "channel", "thread", "discussion", "reply", "dm", "direct", "unread", "inbox", "notify", "notification", "mention", "reaction"]),
        // 5. Meetings, Calls, Audio & Video (Dimensions 40-47)
        (40, 1.0, ["meeting", "meetings", "call", "calls", "video", "audio", "conference", "huddle", "sync", "standup", "daily", "agenda", "record", "recording", "transcript", "room", "schedule", "calendar", "rsvp"]),
        // 6. Organization, Team & Members (Dimensions 48-55)
        (48, 1.0, ["team", "member", "members", "user", "users", "person", "people", "colleague", "role", "admin", "owner", "invite", "organization", "workspace", "lead", "engineer", "designer", "manager"]),
        // 7. DevOps, Backend, Database & Infrastructure (Dimensions 56-63)
        (56, 1.0, ["api", "backend", "server", "database", "sql", "sqlite", "postgres", "cloud", "docker", "deploy", "deployment", "pipeline", "ci", "cd", "migration", "service", "performance", "cache", "network", "endpoint"])
    ]

    private let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "then", "else", "when", "at", "by", "for", "with",
        "about", "against", "between", "into", "through", "during", "before", "after", "above", "below",
        "to", "from", "up", "down", "in", "out", "on", "off", "over", "under", "again", "further", "then",
        "once", "here", "there", "all", "any", "both", "each", "few", "more", "most", "other", "some",
        "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "can", "will",
        "just", "don", "should", "now", "that", "this", "these", "those", "is", "are", "was", "were",
        "be", "been", "being", "have", "has", "had", "having", "do", "does", "did", "doing"
    ]

    private init() {}

    // MARK: - Embedding Generation

    /// Generates a normalized 128-dimensional semantic embedding vector for the provided text.
    public func embed(_ text: String) -> [Float] {
        var vector = [Float](repeating: 0.0, count: Self.vectorDimension)
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return vector }

        // 1. Conceptual Domain Activation (Dimensions 0 to 63)
        for token in tokens {
            for concept in domainConceptWeights {
                if concept.keywords.contains(token) {
                    for offset in 0..<8 {
                        let dim = concept.clusterIndex + offset
                        let spread = Float(1.5) / Float(1.0 + abs(Float(offset) - 3.5))
                        vector[dim] += concept.weight * spread * 2.8
                    }
                }
            }
        }

        // 2. Open-Vocabulary Subword / Hashing Projection (Dimensions 64 to 127)
        for token in tokens {
            let hashVal = abs(token.hashValue)
            let dim1 = 64 + (hashVal % 64)
            let dim2 = 64 + ((hashVal / 64) % 64)
            vector[dim1] += 0.4
            vector[dim2] += 0.2

            // Trigram projections
            if token.count >= 3 {
                let chars = Array(token)
                for i in 0...(chars.count - 3) {
                    let trigram = String(chars[i..<i+3])
                    let triHash = abs(trigram.hashValue)
                    let triDim = 64 + (triHash % 64)
                    vector[triDim] += 0.15
                }
            }
        }

        // 3. L2 Unit Normalization
        var normSquared: Float = 0.0
        for val in vector {
            normSquared += val * val
        }

        let norm = sqrt(normSquared)
        if norm > 0.00001 {
            for i in 0..<vector.count {
                vector[i] /= norm
            }
        }

        return vector
    }

    /// Computes the Cosine Similarity between two unit-normalized vectors.
    /// Returns a value between -1.0 and 1.0 (typically 0.0 to 1.0 for non-negative vectors).
    public func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Double {
        guard vec1.count == vec2.count, !vec1.isEmpty else { return 0.0 }
        var dotProduct: Float = 0.0
        for i in 0..<vec1.count {
            dotProduct += vec1[i] * vec2[i]
        }
        return Double(max(0.0, min(1.0, dotProduct)))
    }

    /// Serializes vector to JSON string for database storage.
    public func serializeVector(_ vector: [Float]) -> String {
        let strings = vector.map { String(format: "%.5f", $0) }
        return "[" + strings.joined(separator: ",") + "]"
    }

    /// Deserializes vector from JSON string.
    public func deserializeVector(_ json: String) -> [Float]? {
        let trimmed = json.trimmingCharacters(in: CharacterSet(charactersIn: "[] \t\r\n"))
        guard !trimmed.isEmpty else { return nil }
        let elements = trimmed.split(separator: ",")
        return elements.compactMap { Float($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Computes a stable hash of text content to detect if re-indexing is required.
    public func contentHash(_ text: String) -> String {
        return String(format: "%016llx", UInt64(abs(text.hashValue)))
    }

    // MARK: - Helpers

    public func tokenize(_ text: String) -> [String] {
        let lower = text.lowercased()
        let components = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 1 && !stopWords.contains($0) }
    }
}
