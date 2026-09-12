import Crypto
import Foundation
import JWT
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

    private struct VideoGrant: Codable {
        let room: String
        let roomJoin: Bool
        let canPublish: Bool
        let canSubscribe: Bool
        let canPublishData: Bool
        let canPublishSources: [String]?
        let roomAdmin: Bool
        let roomCreate: Bool
    }

    private struct Payload: JWTPayload {
        let issuer: IssuerClaim
        let subject: SubjectClaim
        let issuedAt: IssuedAtClaim
        let notBefore: NotBeforeClaim
        let expiration: ExpirationClaim
        let id: IDClaim
        let name: String
        let video: VideoGrant

        func verify(using signer: JWTSigner) throws {
            try expiration.verifyNotExpired()
            try notBefore.verifyNotBefore()
        }
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

        let payload = Payload(
            issuer: IssuerClaim(value: apiKey),
            subject: SubjectClaim(value: identity),
            issuedAt: IssuedAtClaim(value: now),
            notBefore: NotBeforeClaim(value: now.addingTimeInterval(-5)),
            expiration: ExpirationClaim(value: exp),
            id: IDClaim(value: UUID().uuidString),
            name: displayName,
            video: VideoGrant(
                room: roomName,
                roomJoin: true,
                canPublish: grants.canPublish,
                canSubscribe: grants.canSubscribe,
                canPublishData: grants.canPublishData,
                canPublishSources: grants.canPublishSources,
                roomAdmin: grants.roomAdmin,
                roomCreate: grants.roomCreate
            )
        )
        guard let token = try? JWTSigner.hs256(key: apiSecret).sign(payload) else {
            return SignedToken(token: "dev_\(UUID().uuidString)_\(roomName)_\(identity)", expiresAt: exp, serverUrl: nil, isReal: false)
        }
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
