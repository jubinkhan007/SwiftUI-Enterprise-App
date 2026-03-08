import Foundation
import CryptoKit

enum WebhookSigning {
    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func timestampString(for date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    static func signature(secret: String, timestamp: String, body: Data) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        var signed = Data(timestamp.utf8)
        signed.append(0x2e) // '.'
        signed.append(body)
        let mac = HMAC<SHA256>.authenticationCode(for: signed, using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    static func randomSecret(length: Int = 32) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var result = String()
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(alphabet.randomElement()!)
        }
        return result
    }
}

