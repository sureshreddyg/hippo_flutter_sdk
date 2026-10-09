import Flutter
import UIKit
import UserNotifications
import Hippo

/// Hippo's iOS SDK for Flutter (Hippo 2.1.66 or later: `updateUnreadCount`, `getUnreadAnnouncementCount` and the
/// announcement delegate call).
///
/// - Unread counts, as the Hippo team advised: `HippoConfig.shared.updateUnreadCount(completion:)` for messages and
///   `getUnreadAnnouncementCount(completion:)` for announcements. Hippo answers the second through
///   `HippoDelegate.hippoAnnouncementCustomerUnreadCount` (it never calls that completion), so both counts come in
///   through the delegate as well, each on its own event channel with its own last value.
/// - Notifications: Hippo pushes through APNs, so the plugin gives Hippo the APNs token (from the app delegate, or
///   `apnsToken` in the init config), refreshes the counts when a Hippo push arrives, and opens the chat when one is
///   tapped — after `initHippo` if the tap launched the app.
/// - Logging: with `debug` on (debug builds, or `"debug": true` in the init config) every call and callback is logged
///   as `[HippoFlutterSdk]`. Hippo's own logger prints its API calls to the console in every build.
public class HippoFlutterSdkPlugin: NSObject, FlutterPlugin {
    /// The APNs token, kept for a later `initHippo` (it usually arrives first).
    private static var apnsToken: Data?

    private let manager = HippoManager()
    private let messageCounts = CountStream(label: "unread messages")
    private let announcementCounts = CountStream(label: "unread announcements")
    private var isInitialized = false
    private var userDetail: HippoUserDetail?
    /// A Hippo notification tapped before `initHippo` (it launched the app): opened once Hippo is initialised.
    private var pendingTap: [String: Any]?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HippoFlutterSdkPlugin()
        let methodChannel = FlutterMethodChannel(name: "hippo_flutter_sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        FlutterEventChannel(name: "hippo_flutter_sdk_events", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance.messageCounts)
        FlutterEventChannel(name: "hippo_flutter_sdk_announcement_events", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance.announcementCounts)
        // The APNs token and Hippo's notifications come through the app delegate.
        registrar.addApplicationDelegate(instance)
        HippoLog.d("Registered (iOS)")
    }

    override init() {
        super.init()
        manager.onUnreadCount = { [weak self] count in self?.messageCounts.publish(count) }
        manager.onAnnouncementCount = { [weak self] count in self?.announcementCounts.publish(count) }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        HippoLog.d("Dart → \(call.method)")
        switch call.method {
        case "initHippo":
            initHippo(call, result: result)
        case "showConversations":
            guard ready("showConversations", result) else { return }
            HippoLog.d("showConversations: opening Hippo's chats screen")
            HippoConfig.shared.presentChatsViewController()
            result(nil)
        case "openPeerChat":
            openPeerChat(call, result: result)
        case "clearHippoData":
            HippoLog.d("clearHippoData: signing the user out of Hippo; unread counts back to 0")
            HippoConfig.shared.clearHippoUserData { success in
                HippoLog.d("clearHippoData: Hippo answered \(success)")
            }
            isInitialized = false
            userDetail = nil
            pendingTap = nil
            messageCounts.publish(0)
            announcementCounts.publish(0)
            result(nil)
        case "getUnreadCount":
            getUnreadCount(result)
        case "getUnreadAnnouncementCount":
            getUnreadAnnouncementCount(result)
        case "isHippoNotification":
            let data = call.arguments as? [String: Any] ?? [:]
            let isHippo = HippoConfig.shared.isHippoNotification(withUserInfo: data)
            HippoLog.d("isHippoNotification: \(isHippo) (push_source \(data["push_source"] ?? "none"))")
            result(isHippo)
        case "handleHippoNotification":
            let data = call.arguments as? [String: Any] ?? [:]
            guard HippoConfig.shared.isHippoNotification(withUserInfo: data) else {
                HippoLog.d("handleHippoNotification: not a Hippo message; ignored")
                result(false)
                return
            }
            // APNs shows Hippo's notifications on iOS; a message passed from Dart only updates the counts.
            HippoLog.d("handleHippoNotification: updating the unread counts (channel \(data["channel_id"] ?? "?"))")
            hippoPushArrived(data)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Methods

    private func initHippo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? String, let json = data.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid data", details: nil))
            return
        }
        if let debug = dict["debug"] as? Bool {
            HippoLog.enabled = debug
        }
        guard let appKey = dict["appKey"] as? String, !appKey.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "appKey is missing", details: nil))
            return
        }
        let appType = dict["appType"] as? String
        HippoLog.d("initHippo: appKey \(HippoLog.mask(appKey)), appType \(appType ?? "(default)")")
        HippoConfig.shared.setCredential(withAppSecretKey: appKey, appType: appType)

        // The APNs token before the user is sent: Hippo sends it with the user, and needs it to push to this device.
        if let hex = dict["apnsToken"] as? String, let token = HippoLog.data(fromHex: hex) {
            HippoFlutterSdkPlugin.apnsToken = token
        }
        if let token = HippoFlutterSdkPlugin.apnsToken {
            HippoLog.d("initHippo: registering the APNs token with Hippo (\(token.count) bytes)")
            HippoConfig.shared.registerDeviceToken(deviceToken: token)
        } else {
            HippoLog.d("initHippo: no APNs token yet; Hippo gets it when iOS gives it to the app")
        }

        // The delegate first: Hippo reports the counts while it signs the user in.
        HippoConfig.shared.setHippoDelegate(delegate: manager)

        guard let userData = dict["userData"] as? [String: Any] else {
            HippoLog.d("initHippo: no userData; Hippo is set up without a user")
            isInitialized = true
            result(nil)
            return
        }
        guard let userUniqueKey = userData["userUniqueKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "userUniqueKey is missing", details: nil))
            return
        }
        let secret = userData["userIdentificationSecret"] as? String ?? dict["userIdentificationSecret"] as? String
        let detail = HippoUserDetail(fullName: userData["fullName"] as? String ?? "",
                                     email: userData["email"] as? String ?? "",
                                     phoneNumber: userData["phoneNumber"] as? String ?? "",
                                     userUniqueKey: userUniqueKey,
                                     userIdenficationSecret: secret,
                                     selectedlanguage: userData["selectedlanguage"] as? String,
                                     fetchAnnouncementsUnreadCount: true)
        userDetail = detail
        HippoLog.d("initHippo: signing in user \(userUniqueKey) (identification secret \(secret == nil ? "none" : "set"), "
            + "announcement count on)")
        let started = Date()
        HippoConfig.shared.updateUserDetail(userDetail: detail) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let outcome = success ? "ok" : "FAILED — check appKey, userUniqueKey and userIdentificationSecret"
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                HippoLog.d("initHippo: Hippo answered the user sign-in: \(outcome) (\(ms) ms)")
                self.isInitialized = true
                result(nil)
                self.refreshCounts()
                if let tap = self.pendingTap {
                    self.pendingTap = nil
                    HippoLog.d("initHippo: opening the Hippo notification tapped at launch")
                    HippoConfig.shared.handleRemoteNotification(userInfo: tap)
                }
            }
        }
    }

    private func openPeerChat(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard ready("openPeerChat", result) else { return }
        guard let data = call.arguments as? String, let json = data.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid data for peer chat", details: nil))
            return
        }
        guard let transactionId = dict["transactionId"] as? String,
              let myUniqueId = dict["userUniqueKey"] as? String,
              let otherUserUniqueKeys = dict["otherUserUniqueKeys"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required fields for peer chat", details: nil))
            return
        }
        let channelName = dict["channelName"] as? String ?? ""
        let peerName = dict["peerName"] as? String ?? ""
        guard let option = PeerToPeerChat(uniqueChatId: transactionId,
                                          myUniqueId: myUniqueId,
                                          idsOfPeers: otherUserUniqueKeys,
                                          channelName: channelName,
                                          peerName: peerName) else {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to create PeerToPeerChat option", details: nil))
            return
        }
        HippoLog.d("openPeerChat: opening the chat screen — transactionId \(transactionId), channel \"\(channelName)\", "
            + "user \(myUniqueId), with \(otherUserUniqueKeys)")
        let started = Date()
        HippoConfig.shared.showPeerChatWith(data: option) { success, error in
            DispatchQueue.main.async {
                let outcome = success ? "chat shown" : "FAILED: " + (error?.localizedDescription ?? "no reason")
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                HippoLog.d("openPeerChat: \(outcome) (\(ms) ms)")
                result(success)
            }
        }
    }

    private func getUnreadCount(_ result: @escaping FlutterResult) {
        guard isInitialized else {
            HippoLog.d("getUnreadCount: Hippo isn't initialised; answering the last count known, \(messageCounts.lastOrZero)")
            result(messageCounts.lastOrZero)
            return
        }
        HippoLog.d("getUnreadCount: asking Hippo (updateUnreadCount)")
        let started = Date()
        HippoConfig.shared.updateUnreadCount { [weak self] count in
            HippoLog.d("getUnreadCount: Hippo answered \(count) (\(Int(Date().timeIntervalSince(started) * 1000)) ms)")
            self?.messageCounts.publish(count)
            DispatchQueue.main.async { result(count) }
        }
    }

    private func getUnreadAnnouncementCount(_ result: @escaping FlutterResult) {
        guard isInitialized else {
            HippoLog.d("getUnreadAnnouncementCount: Hippo isn't initialised; answering the last count known, "
                + "\(announcementCounts.lastOrZero)")
            result(announcementCounts.lastOrZero)
            return
        }
        // Hippo answers through hippoAnnouncementCustomerUnreadCount (it doesn't call this completion): wait for that.
        announcementCounts.awaitNext(result)
        HippoLog.d("getUnreadAnnouncementCount: asking Hippo (getUnreadAnnouncementCount)")
        HippoConfig.shared.getUnreadAnnouncementCount { [weak self] count in
            HippoLog.d("getUnreadAnnouncementCount: Hippo answered \(count)")
            self?.announcementCounts.publish(count)
        }
    }

    /// Both counts, fresh from Hippo: after signing in, and when a Hippo push arrives.
    private func refreshCounts() {
        guard isInitialized else { return }
        HippoLog.d("Refreshing both unread counts from Hippo")
        HippoConfig.shared.updateUnreadCount { [weak self] count in self?.messageCounts.publish(count) }
        HippoConfig.shared.getUnreadAnnouncementCount { [weak self] count in self?.announcementCounts.publish(count) }
    }

    /// A Hippo push arrived (foreground, background, or passed from Dart): Hippo's own counters, then fresh counts.
    private func hippoPushArrived(_ userInfo: [String: Any]) {
        HippoConfig.shared.managePromotionOrP2pCount(userInfo)
        refreshCounts()
    }

    private func ready(_ method: String, _ result: FlutterResult) -> Bool {
        guard isInitialized else {
            HippoLog.d("\(method): Hippo isn't initialised (call initHippo first)")
            result(FlutterError(code: "NOT_INITIALIZED", message: "\(method) needs initHippo first", details: nil))
            return false
        }
        return true
    }

    // MARK: - App delegate (the app's AppDelegate calls super, so Flutter forwards these to every plugin)

    public func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        HippoLog.d("APNs token from iOS (\(deviceToken.count) bytes): registering it with Hippo")
        HippoFlutterSdkPlugin.apnsToken = deviceToken
        HippoConfig.shared.registerDeviceToken(deviceToken: deviceToken)
        // Hippo sends the token with the user: send the user again when it came after initHippo.
        if isInitialized, let detail = userDetail {
            HippoConfig.shared.updateUserDetail(userDetail: detail) { success in
                HippoLog.d("APNs token sent to Hippo with the user: \(success ? "ok" : "FAILED")")
            }
        }
    }

    public func application(_ application: UIApplication,
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        let info = HippoLog.stringKeys(userInfo)
        if HippoConfig.shared.isHippoNotification(withUserInfo: info) {
            HippoLog.d("Hippo push received (background): updating the unread counts")
            hippoPushArrived(info)
        }
        // Not handled here: the other plugins (firebase_messaging…) answer iOS.
        return false
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let info = HippoLog.stringKeys(notification.request.content.userInfo)
        guard HippoConfig.shared.isHippoNotification(withUserInfo: info) else { return }
        HippoLog.d("Hippo push arrived in the foreground: updating the unread counts")
        hippoPushArrived(info)
        // The completion handler is the app's and the other plugins' to call: this only observes.
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = HippoLog.stringKeys(response.notification.request.content.userInfo)
        guard HippoConfig.shared.isHippoNotification(withUserInfo: info) else { return }
        if isInitialized {
            HippoLog.d("Hippo notification tapped: opening the chat (channel \(info["channel_id"] ?? "?"))")
            HippoConfig.shared.handleRemoteNotification(userInfo: info)
        } else {
            HippoLog.d("Hippo notification tapped before initHippo: opening the chat once Hippo is initialised")
            pendingTap = info
        }
        // The completion handler is the app's and the other plugins' to call: this only observes.
    }
}

/// One unread count: its event channel's listener, its last value, and the calls waiting for Hippo's answer.
final class CountStream: NSObject, FlutterStreamHandler {
    private static let wait: TimeInterval = 8

    let label: String
    private var sink: FlutterEventSink?
    private var last: Int?
    private var waiting: [(id: UUID, result: FlutterResult)] = []

    init(label: String) {
        self.label = label
    }

    var lastOrZero: Int { last ?? 0 }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        HippoLog.d("Dart is listening for \(label)\(last.map { "; sending the last count, \($0)" } ?? "")")
        if let last = last {
            events(last)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        HippoLog.d("Dart stopped listening for \(label)")
        return nil
    }

    /// A count from Hippo, on any thread: kept, sent to Dart, and given to every call waiting for it.
    func publish(_ count: Int) {
        DispatchQueue.main.async {
            HippoLog.d("Hippo callback: \(self.label) = \(count)")
            self.last = count
            self.sink?(count)
            let answered = self.waiting
            self.waiting.removeAll()
            answered.forEach { $0.result(count) }
        }
    }

    /// Answers `result` with Hippo's next count, or the last one known after a while (main thread).
    func awaitNext(_ result: @escaping FlutterResult) {
        let id = UUID()
        waiting.append((id: id, result: result))
        DispatchQueue.main.asyncAfter(deadline: .now() + CountStream.wait) {
            guard let index = self.waiting.firstIndex(where: { $0.id == id }) else { return }
            self.waiting.remove(at: index)
            HippoLog.d("No \(self.label) from Hippo within \(Int(CountStream.wait)) s; answering the last count known, "
                + "\(self.lastOrZero)")
            result(self.lastOrZero)
        }
    }
}

/// Hippo's delegate: the counts it reports, and a log line for everything else it tells the app.
final class HippoManager: HippoDelegate {
    var onUnreadCount: ((Int) -> Void)?
    var onAnnouncementCount: ((Int) -> Void)?

    func hippoUnreadCount(_ totalCount: Int) {
        onUnreadCount?(totalCount)
    }

    func hippoAnnouncementCustomerUnreadCount(_ totalCount: Int) {
        onAnnouncementCount?(totalCount)
    }

    func hippoUserUnreadCount(_ usersCount: [String: Int]) {
        HippoLog.d("Hippo delegate: unread count by user \(usersCount)")
    }

    func sendp2pUnreadCount(unreadCount: Int, channelId: Int) {
        HippoLog.d("Hippo delegate: peer chat \(channelId) unread \(unreadCount)")
    }

    func hippoDeinit() {
        HippoLog.d("Hippo delegate: Hippo screen closed")
    }

    func hippoDidLoad() {
        HippoLog.d("Hippo delegate: Hippo screen opened")
    }

    func hippoMessageRecievedWith(response: [String: Any], viewController: UIViewController) {
        HippoLog.d("Hippo delegate: message received on \(type(of: viewController)) (keys \(response.keys.sorted()))")
    }

    func promotionMessageRecievedWith(response: [String: Any], viewController: UIViewController) {
        HippoLog.d("Hippo delegate: announcement received (keys \(response.keys.sorted()))")
    }

    func deepLinkClicked(response: [String: Any]) {
        HippoLog.d("Hippo delegate: deep link clicked (keys \(response.keys.sorted()))")
    }

    func hippoUserLogOut() {
        HippoLog.d("Hippo delegate: user logged out")
    }

    func startLoading(message: String?) {}

    func stopLoading() {}

    func hippoAgentTotalUnreadCount(_ totalCount: Int) {}

    func hippoAgentTotalChannelsUnreadCount(_ totalCount: Int) {}

    func sendDataIfChatIsAssignedToSelfAgent(_ dic: [String: Any]) {}

    func chatListButtonAction() {
        HippoLog.d("Hippo delegate: chat list button tapped")
    }

    func passSecurityCheckError(error: String) {
        HippoLog.d("Hippo delegate: security check error: \(error)")
    }

    #if canImport(HippoCallClient)
    func loadCallPresenterView(request: CallPresenterRequest) -> CallPresenter? {
        return nil
    }
    #endif
}

/// The plugin's log: on in debug builds, or as the init config's `"debug"` says.
enum HippoLog {
    #if DEBUG
    static var enabled = true
    #else
    static var enabled = false
    #endif

    static func d(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        NSLog("[HippoFlutterSdk] %@", message())
    }

    /// A key, secret or token as a log shows it: its first four characters and its length.
    static func mask(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "(none)" }
        return value.count <= 4 ? "…(\(value.count))" : "\(value.prefix(4))…(\(value.count))"
    }

    /// An APNs token written as hex ("<ab12 …>" or "ab12…") as the bytes Hippo takes.
    static func data(fromHex hex: String) -> Data? {
        let clean = hex.filter { $0.isHexDigit }
        guard !clean.isEmpty, clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    /// A notification's userInfo with string keys, as Hippo takes it.
    static func stringKeys(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var info: [String: Any] = [:]
        for (key, value) in userInfo {
            info["\(key)"] = value
        }
        return info
    }
}
