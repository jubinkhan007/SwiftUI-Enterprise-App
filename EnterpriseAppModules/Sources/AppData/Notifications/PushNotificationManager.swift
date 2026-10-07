import Foundation
import Combine
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
import Domain
import AppNetwork
import SharedModels

@MainActor
public final class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = PushNotificationManager()

    @Published public var deviceToken: String? = nil
    @Published public var isAuthorized: Bool = false
    @Published public var pendingDeeplink: DeeplinkDestination? = nil

    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    public init(
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.configuration = configuration
        super.init()
    }

    public func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task {
            await checkAuthorization()
        }
    }

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            self.isAuthorized = granted
            #if os(iOS)
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
            return granted
        } catch {
            print("Failed to request push notification permissions: \(error)")
            return false
        }
    }

    public func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    }

    public func registerDeviceTokenData(_ deviceTokenData: Data) {
        let tokenParts = deviceTokenData.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token

        Task {
            await uploadToken(token)
        }
    }

    public func uploadToken(_ token: String) async {
        let endpoint = DeviceTokenEndpoint.register(
            token: token,
            platform: "ios",
            environment: "development",
            configuration: configuration
        )
        do {
            _ = try await apiClient.request(endpoint, responseType: APIResponse<DeviceTokenDTO>.self)
            print("PushNotificationManager: Device token registered successfully.")
        } catch {
            print("PushNotificationManager: Failed to register device token: \(error)")
        }
    }

    public func unregisterDeviceToken() async {
        guard let token = deviceToken else { return }
        let endpoint = DeviceTokenEndpoint.unregister(token: token, configuration: configuration)
        do {
            _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
            self.deviceToken = nil
        } catch {
            print("PushNotificationManager: Failed to unregister device token: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if os(iOS)
        completionHandler([.banner, .badge, .sound])
        #else
        completionHandler([.badge, .sound])
        #endif
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let deepLinkString = (userInfo["deep_link"] as? String)
            ?? (userInfo["deepLink"] as? String)
            ?? (userInfo["url"] as? String)

        if let deepLinkString = deepLinkString,
           let dest = DeeplinkParser.parse(urlString: deepLinkString) {
            Task { @MainActor in
                PushNotificationManager.shared.pendingDeeplink = dest
                DeeplinkRouter.shared.route(destination: dest)
            }
        }
        completionHandler()
    }
}

