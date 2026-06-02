import Crypto
import Foundation
import Vapor

/// LiveKit-compatible JWT token signer.
///
/// Matches the claims structure expected by `livekit-server-sdk` and the
/// `livekit-client-swift` SDK:
///   {
///     "iss":   "<API_KEY>",
///     "sub":   "<identity>",
///     "iat":   <unix>,
///     "exp":   <unix>,
///     "nbf":   <unix>,
///     "jti":   "<uuid>",
///     "video": {
///       "room":            "<roomName>",
///       "roomJoin":        true,
///       "canPublish":      true|false,
///       "canSubscribe":    true|false,
///       "canPublishData":  true|false
///     },
///     "name":  "<displayName>"
///   }
///
/// When `LIVEKIT_API_KEY` + `LIVEKIT_API_SECRET` env vars are set, tokens are
/// real and accepted by a LiveKit server. Without them, returns `dev_<...>`
/// placeholder strings the iOS client recognizes and refuses to send to an SFU.
enum LiveKitTokenSigner {
    struct Grants: Sendable {
        var canPublish: Bool = true
        var canSubscribe: Bool = true
        var canPublishData: Bool = true
        var canPublishSources: [String]? = nil  // ["camera", "microphone", "screen_share"]
        var roomAdmin: Bool = false
        var roomCreate: Bool = false
    }

    struct SignedToken: Sendable {
        let token: String
        let expiresAt: Date
        let serverUrl: String?
        /// `true` if real env-backed signing was used.
        let isReal: Bool
    }

    static let defaultTtl: TimeInterval = 6 * 60 * 60  // 6h

    static func sign(
        roomName: String,
        identity: String,
        displayName: String,
        grants: Grants = Grants(),
        ttl: TimeInterval = defaultTtl
    ) -> SignedToken {
        let now = Date()
        let exp = now.addingTimeInterval(ttl)

        let apiKey = Environment.get("LIVEKIT_API_KEY") ?? ""
        let apiSecret = Environment.get("LIVEKIT_API_SECRET") ?? ""
        let serverUrl = Environment.get("LIVEKIT_URL")

        guard !apiKey.isEmpty, !apiSecret.isEmpty else {
            // Dev fallback — clients must not send these to a real SFU.
            return SignedToken(
                token: "dev_\(UUID().uuidString)_\(roomName)_\(identity)",
                expiresAt: exp,
                serverUrl: nil,
                isReal: false
            )
        }

        let header = Self.base64URL(json: [
            "alg": "HS256",
            "typ": "JWT"
        ])

        var video: [String: Any] = [
            "room": roomName,
            "roomJoin": true,
            "canPublish": grants.canPublish,
            "canSubscribe": grants.canSubscribe,
            "canPublishData": grants.canPublishData,
            "roomAdmin": grants.roomAdmin,
            "roomCreate": grants.roomCreate
        ]
        if let sources = grants.canPublishSources {
            video["canPublishSources"] = sources
        }

        let payload: [String: Any] = [
            "iss": apiKey,
            "sub": identity,
            "name": displayName,
            "iat": Int(now.timeIntervalSince1970),
            "nbf": Int(now.timeIntervalSince1970),
            "exp": Int(exp.timeIntervalSince1970),
            "jti": UUID().uuidString,
            "video": video
        ]

        let body = Self.base64URL(json: payload)
        let signingInput = "\(header).\(body)"

        let key = SymmetricKey(data: Data(apiSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let signature = Self.base64URLEncode(Data(mac))

        let token = "\(signingInput).\(signature)"
        return SignedToken(token: token, expiresAt: exp, serverUrl: serverUrl, isReal: true)
    }

    // MARK: - Encoding helpers

    private static func base64URL(json object: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return base64URLEncode(data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
